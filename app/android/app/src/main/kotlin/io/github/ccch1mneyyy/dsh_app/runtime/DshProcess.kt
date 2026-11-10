package io.github.ccch1mneyyy.dsh_app.runtime

import android.content.Context
import java.io.BufferedReader
import java.io.File
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.ServerSocket
import java.net.Socket
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import kotlin.concurrent.thread

/**
 * Runs the bundled native Go engine (`libdsh.so`) as an out-of-process child.
 *
 * The engine is fully Android-native: no PRoot, no Ubuntu guest, no Node
 * bootstrap, no launch overlays. Its home, workspace, agents home and temp
 * paths come from [NativeRuntimePaths]. This class only picks the port,
 * supplies the environment, watches stdout for the launch token, and owns the
 * child's lifecycle.
 */
class DshProcess(
    private val context: Context,
    private val manifest: RuntimeManifest,
    private val listener: Listener,
) {
    interface Listener {
        fun onLog(line: String, stream: String)
        fun onReady(source: DshProcess, baseUrl: String, token: String)
        fun onExit(source: DshProcess, code: Int, expected: Boolean)
        /** Called under the process monitor: enqueue owner updates without waiting for its lock. */
        fun onStartupFailure(source: DshProcess)
        /** Retained for the controller's status surface; the native engine has no file tidy step. */
        fun onTidying(active: Boolean) {}
    }

    @Volatile private var process: Process? = null
    @Volatile private var stopping = false
    @Volatile private var expectedExit = false
    @Volatile private var readyReported = false
    private val startupSignal = CountDownLatch(1)
    @Volatile private var waiter: Thread? = null
    @Volatile private var stopper: Thread? = null

    /** Always false: the native engine has no separate direct-glibc launch mode. */
    val direct: Boolean = false

    var port: Int = DEFAULT_PORT
        private set

    @Volatile var startupError: String? = null
        private set

    @Volatile var startupTokenTimedOut: Boolean = false
        private set

    val launchDiagnostics = LaunchDiagnostics()

    /** `native` while the child is alive, otherwise null. */
    val executionMode: String? get() = if (process?.isAlive == true) "native" else null

    fun start(guestEnv: Map<String, String> = emptyMap()) {
        check(process == null) { "already started" }

        val binary = File(context.applicationInfo.nativeLibraryDir, "libdsh.so")
        if (!binary.isFile) {
            failStart("native engine is missing from this APK")
            return
        }
        try {
            // The manifest carries the pinned source revision and binary hash; a
            // missing or mismatched engine block refuses to launch.
            val engine = manifest.engine ?: throw IllegalStateException("runtime manifest has no engine provenance")
            engine.verify(binary)
            listener.onLog(
                "[dsh-app] engine ${engine.revision.take(12)} (${engine.protocolVersion}, ${engine.bytes} bytes)",
                "system",
            )
        } catch (e: Exception) {
            failStart(e.message ?: "native engine verification failed")
            return
        }

        port = pickPort()
        val paths = NativeRuntimePaths.of(context).prepare()
        // The pinned engine accepts `--port`, `--home` and `--workspace`; passing the
        // workspace explicitly keeps it on the same app-owned path even if a caller
        // tries to inject DSH_WORKSPACE_ROOT through [guestEnv].
        val builder = ProcessBuilder(
            binary.absolutePath,
            "--port", port.toString(),
            "--home", paths.home.absolutePath,
            "--workspace", paths.workspaceRoot.absolutePath,
        ).directory(paths.workspaceRoot)
        val env = builder.environment()
        env.clear()
        env["PATH"] = "/system/bin:/system/xbin"
        env["HOME"] = paths.home.absolutePath
        env["DSH_HOME"] = paths.home.absolutePath
        env["AGENTS_HOME"] = paths.agentsHome.absolutePath
        env["DSH_WORKSPACE_ROOT"] = paths.workspaceRoot.absolutePath
        env["TMPDIR"] = paths.tempRoot.absolutePath
        // Caller env may add credentials or feature flags, but it must never redirect
        // the engine away from the app-owned home, agents home, workspace or temp dir.
        guestEnv.forEach { (key, value) -> if (key !in RUNTIME_ENV) env[key] = value }

        readyReported = false
        launchDiagnostics.selected(false, null)
        listener.onLog("[dsh-app] launching native Go engine: ${builder.command().joinToString(" ")}", "system")
        if (stopping) {
            listener.onExit(this, 0, true)
            return
        }

        val child = try {
            builder.start()
        } catch (e: Exception) {
            failStart(e.message ?: e.javaClass.simpleName)
            return
        }
        process = child
        launchDiagnostics.spawned()
        val out = pump(child.inputStream.bufferedReader(), "stdout")
        val err = pump(child.errorStream.bufferedReader(), "stderr")
        waiter = thread(name = "dsh-wait", isDaemon = true) {
            val code = try {
                child.waitFor()
            } catch (_: InterruptedException) {
                -1
            }
            startupSignal.countDown()
            // The fatal message is usually the last output: let the pumps drain it first.
            try {
                out.join(2000)
                err.join(2000)
            } catch (_: InterruptedException) {
            }
            val stopThread = synchronized(this) {
                process = null
                stopper
            }
            stopThread?.join()
            listener.onExit(this, code, expectedExit)
        }
        // The port deadline starts only after a token, so a stuck engine can still
        // fail with evidence rather than hanging forever.
        thread(name = "dsh-start-deadline", isDaemon = true) {
            if (startupSignal.await(TOKEN_TIMEOUT_MS, TimeUnit.MILLISECONDS)) return@thread
            synchronized(this) {
                if (process === child && child.isAlive && !readyReported && !stopping) {
                    startupTokenTimedOut = true
                    failStart("no startup token received within ${TOKEN_TIMEOUT_MS / 1000}s")
                }
            }
        }
        if (stopping) stop()
    }

    /** Waits for cleanup and exit reporting; zero waits until completion. */
    fun awaitExit(millis: Long = 0): Boolean {
        val ending = waiter ?: stopper
        ending?.join(millis)
        return ending?.isAlive != true
    }

    /** Preserve a startup failure through cleanup and the service's later STOP. */
    @Synchronized fun failStart(message: String) {
        if (stopping) {
            stop(expected = false)
            return
        }
        startupError = message
        listener.onLog("[dsh-app] start failed: $message", "system")
        listener.onStartupFailure(this)
        stop(expected = false)
    }

    /** Terminates the engine child, then force-kills it if it does not exit in time. */
    @Synchronized fun stop(expected: Boolean = true) {
        stopping = true
        startupSignal.countDown()
        if (expected) expectedExit = true
        if (stopper != null) return
        val child = process ?: return
        stopper = thread(name = "dsh-stop", isDaemon = true) {
            try {
                if (child.isAlive) child.destroy()
                if (!waitExit(child, 5_000) && child.isAlive) child.destroyForcibly()
                waitExit(child, 2_000)
            } finally {
                if (child.isAlive) child.destroyForcibly()
                child.waitFor()
            }
        }
    }

    private fun waitExit(child: Process, millis: Long): Boolean {
        val deadline = System.nanoTime() + millis * 1_000_000L
        while (child.isAlive && System.nanoTime() < deadline) Thread.sleep(100)
        return !child.isAlive
    }

    private fun pump(reader: BufferedReader, stream: String) = thread(name = "dsh-$stream", isDaemon = true) {
        try {
            reader.useLines { lines ->
                lines.forEach { line ->
                    listener.onLog(line, stream)
                    if (!readyReported) detectToken(line)
                }
            }
        } catch (_: Exception) {
        }
    }

    @Synchronized private fun detectToken(line: String) {
        if (readyReported || stopping) return
        val match = TOKEN_URL.find(line) ?: return
        val url = match.value
        val token = TOKEN_PARAM.find(url)?.groupValues?.get(1) ?: return
        val parsedPort = Regex("""https?://[^:/]+:(\d+)""").find(url)?.groupValues?.get(1)?.toIntOrNull()
        if (parsedPort != null) port = parsedPort
        readyReported = true
        startupSignal.countDown()
        val base = "http://127.0.0.1:$port"
        thread(name = "dsh-ready", isDaemon = true) {
            val deadline = System.currentTimeMillis() + 90_000
            while (System.currentTimeMillis() < deadline && !stopping && process?.isAlive == true) {
                if (canConnect(port)) {
                    listener.onReady(this, base, token)
                    return@thread
                }
                Thread.sleep(250)
            }
            if (!stopping && process?.isAlive == true) {
                failStart("token seen but port $port never accepted connections")
            }
        }
    }

    companion object {
        const val DEFAULT_PORT = 3080
        private val RUNTIME_ENV = setOf(
            "PATH", "HOME", "DSH_HOME", "AGENTS_HOME", "DSH_WORKSPACE_ROOT", "TMPDIR",
        )
        // Bootstrap budget (not a device measurement); token-to-port retains its own 90 seconds.
        private const val TOKEN_TIMEOUT_MS = 180_000L
        private val TOKEN_URL = Regex("""https?://[^\s'"]*[?&#]token=[A-Za-z0-9._~%-]+""")
        private val TOKEN_PARAM = Regex("""[?&#]token=([A-Za-z0-9._~%-]+)""")

        fun canConnect(port: Int): Boolean = try {
            Socket().use { it.connect(InetSocketAddress("127.0.0.1", port), 500); true }
        } catch (_: Exception) {
            false
        }

        fun pickPort(): Int {
            for (candidate in DEFAULT_PORT..DEFAULT_PORT + 20) {
                try {
                    ServerSocket(candidate, 1, InetAddress.getByName("127.0.0.1")).close()
                    return candidate
                } catch (_: Exception) {
                }
            }
            return ServerSocket(0, 1, InetAddress.getByName("127.0.0.1")).use { it.localPort }
        }
    }
}
