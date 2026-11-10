package io.github.ccch1mneyyy.dsh_app.runtime

import io.github.ccch1mneyyy.dsh_app.i18n.AppStrings
import io.github.ccch1mneyyy.dsh_app.R
import android.content.Context
import android.content.Intent
import android.net.LinkProperties
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import io.github.ccch1mneyyy.dsh_app.phone.PhoneControl
import org.json.JSONArray
import org.json.JSONObject
import io.github.ccch1mneyyy.dsh_app.phone.skills.PhoneSkillRoute
import java.io.File
import java.util.concurrent.Executors

/**
 * Process-wide owner of the local runtime: install state, the DSH process, logs, and the
 * failure detection / safe mode around it.
 * The Flutter plugin and the foreground service both talk to this singleton.
 */
class RuntimeController private constructor(private val app: Context) : DshProcess.Listener {

    enum class Phase(val wire: String) {
        NOT_INSTALLED("notInstalled"), INSTALLING("installing"), INSTALLED("installed"),
        STARTING("starting"), RUNNING("running"), STOPPING("stopping"), ERROR("error"),
    }

    fun interface EventSink {
        fun emit(event: Map<String, Any?>)
    }

    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor { r -> Thread(r, "dsh-runtime") }
    private val sinks = LinkedHashSet<EventSink>()
    private val statusPublishLock = Any()
    private val logDir = NativeRuntimePaths.of(app).logs
    private val runtimeLogs = RuntimeLogs(
        File(logDir, "dsh.log"), SystemClock::elapsedRealtime,
        post = { action -> main.post { action() } },
        deliver = { entries ->
            val event = mapOf("type" to "logs", "entries" to entries.map { it.toMap() })
            val targets = synchronized(sinks) { sinks.toList() }
            targets.forEach { it.emit(event) }
        },
    )
    private val lkgFile = File(app.filesDir, "native/lkg/lkg.json")
    private val prefs = app.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private val workspaceRecovery = WorkspaceRecoveryMode(prefs.getBoolean(K_WORKSPACE_RECOVERY, false))

    val manifest: RuntimeManifest by lazy { RuntimeManifest.load(app) }
    private val installer by lazy { RuntimeInstaller(app, manifest, ::note) }
    /** Guest-path view of the native homes for the recovery readers. */
    private val guestRoot by lazy { NativeRuntimePaths.of(app).guestRoot() }
    @Volatile private var process: DshProcess? = null
    @Volatile private var lastLaunch: LaunchDiagnostics? = null
    /** Retained for the Flutter status contract; the native engine has no file tidy step. */
    @Volatile private var tidyingFiles = false

    @Volatile var phase: Phase = Phase.NOT_INSTALLED
        private set
    @Volatile private var baseUrl: String? = null
    @Volatile private var token: String? = null
    @Volatile private var error: String? = null
    @Volatile private var pendingEnv: Map<String, String> = emptyMap()
    /** Whether the managed AGENTS.md tells the model about ```dsh-ui views (settings, on by default). */
    @Volatile private var pendingVisualReplies = true
    /** Kept for the Flutter channel contract; native tools cannot see /sdcard either. */
    @Volatile private var pendingPhoneStorage = false
    /** One launch log line per process for settings the native engine cannot honor. */
    @Volatile private var notedNativeLimits = false

    // Safe mode and failure detection. State that must survive the app being killed lives in [prefs].
    @Volatile private var safeState = SafeState.parse(prefs.getString(K_SAFE_STATE, null))
    @Volatile private var safeReason: String? = prefs.getString(K_SAFE_REASON, null)
    @Volatile private var strikes = prefs.getInt(K_STRIKES, 0)
    /** Latest unexpected exit; the failure card shows it until a later run gets going. */
    @Volatile private var failure: RunFailure? = readFailure(K_FAILURE)

    /** Latest failure of the main profile (normal mode): what safe mode is there to fix. */
    @Volatile private var mainFailure: RunFailure? = readFailure(K_MAIN_FAILURE)

    /** Mode of the current (or last) launched process. */
    @Volatile private var runSafe = false
    @Volatile private var runGen = 0
    @Volatile private var stopGen = -1
    @Volatile private var resetting = false
    // A phone draft save may stage only within the ready runtime captured by its button press.
    // Independent of bundled-skill attachment grants; it never borrows their write permission.
    @Volatile private var phoneSkillStoppedGeneration = -1
    // Retire skill writes at the stop request, before the Service receives ACTION_STOP.
    // This gate does not change process lifecycle or A5's ownership/launch decisions.
    private val managedSkillGate = ManagedSkillRuntimeGate()
    private val managedSkills = ManagedSkillQueue(
        execute = { action -> worker.execute { action() } },
        deliver = { action ->
            if (Looper.myLooper() == Looper.getMainLooper()) action() else main.post { action() }
        },
    )
    private val autoRestarts = ArrayDeque<Long>()
    @Volatile private var readyAt: Long? = null
    @Volatile private var healthyAt: Long? = null

    /** The main profile as it was when the current normal run booted; becomes the LKG when healthy. */
    @Volatile private var bootProfile: ProfileSnapshot? = null
    private val runTail = ArrayDeque<String>()
    private val networkAccess = NetworkAccess()

    /** Start → spawn → listening, logged in one line when DSH comes up. */
    private val timeline = StartupTimeline.forThisProcess()

    /** The process being started or running is a safe-mode one. */
    val safeRun: Boolean get() = runSafe

    init {
        phase = try {
            if (installer.isCurrent()) Phase.INSTALLED else Phase.NOT_INSTALLED
        } catch (e: Exception) {
            error = "manifest: ${e.message}"
            Phase.ERROR
        }
    }

    fun addSink(sink: EventSink) = synchronized(sinks) { sinks += sink }
    fun removeSink(sink: EventSink) = synchronized(sinks) { sinks -= sink }

    fun status(): Map<String, Any?> = mapOf(
        "abi" to (runCatching { manifest.abi }.getOrNull() ?: Build.SUPPORTED_ABIS.firstOrNull()),
        "bundledVersion" to runCatching { manifest.runtimeVersion }.getOrNull(),
        "installedVersion" to runCatching { installer.installedVersion() }.getOrNull(),
        "dshVersion" to runCatching { manifest.dshVersion }.getOrNull(),
        "nodeVersion" to runCatching { manifest.nodeVersion }.getOrNull()?.takeIf { it.isNotBlank() && it != "none" },
        "phase" to phase.wire,
        "baseUrl" to baseUrl,
        "token" to token,
        "managedSkillGeneration" to managedSkillGate.generationFor(token),
        "error" to error,
        "mode" to if (currentModeSafe()) "safe" else "normal",
        "safeState" to safeState.wire,
        "safeReason" to safeReason,
        "strikes" to strikes,
        "autoSafe" to autoSafe(),
        "workspaceRecovery" to workspaceRecovery.enabled,
        "failure" to failure?.toMap(),
        "mainFailure" to mainFailure?.toMap(),
        "healthyAt" to healthyAt,
        "networkBlocked" to networkAccess.isBlocked,
        "networkBlockedAt" to networkAccess.blockedAt,
        // Retained for the existing Flutter status contract; the native engine has
        // a single launch path, so there is no direct-glibc alternative.
        "directEngineEnabled" to false,
        "directEngineAvailable" to false,
        "directEngineActive" to false,
        "directEngineFallbackReason" to null,
        "currentExecutionMode" to process?.executionMode,
        "launchSelectedMode" to lastLaunch?.selectedMode,
        "launchSpawned" to (lastLaunch?.spawned == true),
        "launchFailureReason" to lastLaunch?.failureReason,
        "tidyingFiles" to tidyingFiles,
    )

    /** Retained for the Flutter channel; the native engine has one launch path. */
    fun setDirectEngine(@Suppress("UNUSED_PARAMETER") enabled: Boolean) {
        emitStatus()
    }

    /** Selects a separate workspace index for the next launch; never opens either index here. */
    fun setWorkspaceRecovery(enabled: Boolean, onDone: (Throwable?) -> Unit) {
        worker.execute {
            try {
                try {
                    checkRecoveryWrite(mainProfileOnly = false)
                } catch (e: Exception) {
                    // A failed observation is not proof that the old writer has stopped.
                    throw if (e is RuntimeNotStoppedException) e
                    else RuntimeNotStoppedException().apply { initCause(e) }
                }
                workspaceRecovery.set(enabled) { next ->
                    prefs.edit().putBoolean(K_WORKSPACE_RECOVERY, next).commit()
                }
                emitStatus()
                main.post { onDone(null) }
            } catch (e: Throwable) {
                main.post { onDone(e) }
            }
        }
    }

    /** While a process is up: its mode; otherwise the mode the next start will use. */
    private fun currentModeSafe(): Boolean {
        val active = process != null || phase == Phase.STARTING || phase == Phase.RUNNING || phase == Phase.STOPPING
        return if (active) runSafe else safeState == SafeState.ON
    }

    /** [dropKept] is kept for the Flutter channel contract; a native reset never stages anything. */
    @Synchronized fun install(dropKept: Boolean = false, onDone: (Throwable?) -> Unit) {
        if (phase == Phase.INSTALLING) return onDone(null)
        if (installer.isCurrent() && phase != Phase.ERROR && !resetting) {
            if (phase == Phase.NOT_INSTALLED) setPhase(Phase.INSTALLED)
            return onDone(null)
        }
        if (process != null || resetting || phase in setOf(Phase.STARTING, Phase.RUNNING, Phase.STOPPING)) {
            return onDone(RuntimeUpgradeBlocked("running"))
        }
        setPhase(Phase.INSTALLING)
        worker.execute {
            try {
                log("[dsh-app] verifying native engine ${manifest.runtimeVersion} (${manifest.abi})", "system")
                val started = System.currentTimeMillis()
                if (process != null) throw RuntimeUpgradeBlocked("running")
                if (dropKept) log("[dsh-app] installing without what could not be kept", "system")
                installer.install(dropKept) { done, total ->
                    emit(mapOf("type" to "progress", "step" to "extract", "done" to done, "total" to total))
                }
                log("[dsh-app] runtime ready in ${(System.currentTimeMillis() - started) / 1000}s", "system")
                error = null
                // A new runtime may well fix what failed before.
                strikes = 0
                failure = null
                prefs.edit().putInt(K_STRIKES, 0).remove(K_FAILURE).apply()
                setPhase(Phase.INSTALLED)
                main.post { onDone(null) }
            } catch (e: Throwable) {
                error = "install failed: ${e.message}"
                log("[dsh-app] ${error}", "system")
                setPhase(Phase.ERROR)
                main.post { onDone(e) }
            }
        }
    }

    /**
     * Starts the foreground service, which calls [startProcess]. [mode] is "safe", "normal"
     * (leaving safe mode starts a two-minute trial) or null to keep the current mode.
     */
    fun start(
        env: Map<String, String>,
        phoneStorage: Boolean = false,
        mode: String? = null,
        visualReplies: Boolean = pendingVisualReplies,
    ) {
        pendingVisualReplies = visualReplies
        pendingPhoneStorage = phoneStorage
        if (phase == Phase.RUNNING || phase == Phase.STARTING) return
        pendingEnv = env
        val next = SafePolicy.onStartRequest(safeState, mode)
        if (next == SafeState.ON) {
            // The pinned Go engine has no rescue profile or --safe flag. Starting the
            // same home and calling it safe mode would be a lie, so start normal mode.
            log("[dsh-app] safe mode is not available for the native engine; starting normal mode", "system")
            setSafeState(SafeState.OFF, null)
        } else if (next != safeState) {
            setSafeState(next, if (next == SafeState.PROBATION) SafePolicy.REASON_PROBATION else safeReason)
        }
        val intent = Intent(app, DshService::class.java).setAction(DshService.ACTION_START)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) app.startForegroundService(intent) else app.startService(intent)
    }

    fun publishDiagnostics(markdown: String, manual: Boolean = false): Map<String, Any?>? = try {
        if (!installer.isCurrent()) null
        else {
            // Native tools are confined to the engine workspace. Writing under the home
            // (the old guest path) made the report unreadable to the agent.
            val dir = File(NativeRuntimePaths.of(app).workspaceRoot, "dsh-app").apply { mkdirs() }
            val file = File(dir, if (manual) "diagnostics-manual.md" else "diagnostics.md")
            file.writeText(markdown)
            mapOf("path" to file.absolutePath, "bytes" to file.length())
        }
    } catch (_: Exception) {
        null
    }

    fun stop() {
        synchronized(this) { phoneSkillStoppedGeneration = maxOf(phoneSkillStoppedGeneration, runGen) }
        managedSkillGate.stop(runGen)
        val intent = Intent(app, DshService::class.java).setAction(DshService.ACTION_STOP)
        app.startService(intent)
    }

    /** Private bundled-skill transaction; never falls back to a different executor/root. */
    internal fun installManagedSkill(owner: ManagedSkillOwner, raw: Any?, onDone: (Map<String, Any?>) -> Unit) {
        val request = ManagedSkillRequest.parse(raw)
        val run = request?.let { managedSkillGate.capture(owner, it.expectedToken, it.expectedGeneration) }
        if (request == null || run == null) {
            onDone(mapOf("result" to null, "current" to false, "reason" to if (request == null) "invalid" else "stale"))
            return
        }
        // The Dart side sends GuestFs.local().root as expectedRoot; the installer and
        // controller must use that same guest-root view, not the native home.
        managedSkills.submit(owner, request, guestRoot, current = {
            managedSkillGate.current(run) && phase == Phase.RUNNING && runGen == run.runtimeGeneration &&
                stopGen < run.runtimeGeneration && !resetting && token == run.token
        }, onDone = onDone)
    }

    internal fun cancelManagedSkill(owner: ManagedSkillOwner, requestId: String? = null) {
        managedSkills.cancel(owner, requestId)
    }

    /** Original Runtime/root captured at the trusted local button request, never after queueing.
     * This is a read origin, not an invocation or permission to execute a phone action. */
    internal class PhoneSkillOrigin internal constructor(
        internal val runtime: RuntimeController,
        internal val generation: Int,
        internal val root: File,
    )

    @Synchronized internal fun capturePhoneSkillOrigin(): PhoneSkillOrigin? =
        if (phase == Phase.RUNNING && !runSafe && !resetting && stopGen < runGen &&
            phoneSkillStoppedGeneration < runGen) PhoneSkillOrigin(this, runGen, guestRoot) else null

    // Read-only generation fence for physical action gates; never acquires the Runtime monitor.
    // The final generation read rejects mixed fields across an unexpected-exit/restart.
    internal fun phoneSkillOriginCurrent(origin: PhoneSkillOrigin): Boolean =
        origin.runtime === this && phase == Phase.RUNNING && !runSafe && !resetting &&
            runGen == origin.generation && stopGen < origin.generation &&
            phoneSkillStoppedGeneration < origin.generation && runGen == origin.generation

    /** Uses the existing rootfs worker. The only descriptor input is the native reviewed table;
     * private UI/JSON never supplies it. An empty table has no executable App registration.
     * Caller keeps this same origin for pending/claim checks, outside registry/Tasks locks. */
    internal fun readPhoneSkillBundle(origin: PhoneSkillOrigin, name: String, revision: String?,
        descriptors: Map<String, PhoneSkillRoute.Descriptor>,
        onDone: (PhoneSkillBundleReader.Read) -> Unit) {
        val reviewed = java.util.Collections.unmodifiableMap(LinkedHashMap(descriptors))
        worker.execute {
            val result = if (!phoneSkillOriginCurrent(origin)) {
                PhoneSkillBundleReader.Read.Rejected(PhoneSkillBundleReader.Reason.UNAVAILABLE)
            } else PhoneSkillBundleReader.read(origin.root, name, revision, reviewed)
            main.post {
                onDone(if (phoneSkillOriginCurrent(origin)) result
                    else PhoneSkillBundleReader.Read.Rejected(PhoneSkillBundleReader.Reason.UNAVAILABLE))
            }
        }
    }

    /** User-selected phone draft only. Lock order: Controller -> write; no IO under either. */
    internal fun savePhoneSkill(write: PhoneSkillWrite, onDone: (PhoneSkillInstallResult) -> Unit) {
        val origin = capturePhoneSkillOrigin()?.let(write::bindSaveOrigin)
        if (origin == null) {
            val result = PhoneSkillInstallResult.Refused.STALE
            write.finish(result)
            main.post { onDone(result) }
            return
        }
        try { worker.execute {
            fun current(): Boolean = phoneSkillOriginCurrent(origin)
            var result: PhoneSkillInstallResult? = null
            try {
                val bundle = write.bundle
                result = if (bundle == null) PhoneSkillInstaller.install(origin.root, write.document,
                    canStage = { synchronized(this) { current() && write.canStage() } },
                    beginCommit = { synchronized(this) { current() && write.beginCommit() } },
                ) else when (val saved = PhoneSkillBundleInstaller.install(origin.root, bundle,
                    canStage = { synchronized(this) { current() && write.canStage() } },
                    beginCommit = { synchronized(this) { current() && write.beginCommit() } },
                )) {
                    is PhoneSkillBundleInstaller.Result.Saved -> PhoneSkillInstallResult.BundleSaved(saved.identity)
                    is PhoneSkillBundleInstaller.Result.Unverified -> PhoneSkillInstallResult.BundleUnverified(
                        saved.identity, saved.publication, saved.code)
                    PhoneSkillBundleInstaller.Result.Refused.STALE -> PhoneSkillInstallResult.Refused.STALE
                    PhoneSkillBundleInstaller.Result.Refused.NO_HOME -> PhoneSkillInstallResult.Refused.NO_HOME
                    PhoneSkillBundleInstaller.Result.Refused.CONFLICT -> PhoneSkillInstallResult.Refused.CONFLICT
                    PhoneSkillBundleInstaller.Result.Refused.IO, PhoneSkillBundleInstaller.Result.Refused.INVALID -> PhoneSkillInstallResult.Refused.IO
                }
            } finally {
                // Physical completion precedes any UI callback. A permit already consumed is
                // not proof of zero publication when the operation fails without a result.
                val finished = result ?: write.bundle?.takeIf { write.phase() == PhoneSkillWrite.Phase.COMMITTING }?.let {
                    PhoneSkillInstallResult.BundleUnverified(it.identity, PhoneSkillBundleInstaller.Publication.UNKNOWN,
                        PhoneSkillBundleInstaller.Verification.VERIFICATION_UNAVAILABLE)
                } ?: PhoneSkillInstallResult.Refused.IO
                write.finish(finished)
                main.post { onDone(finished) }
            }
        } } catch (_: java.util.concurrent.RejectedExecutionException) {
            // Submission failed: this job cannot enter the reader/installer.
            val result = PhoneSkillInstallResult.Refused.IO
            write.finish(result)
            main.post { onDone(result) }
        }
    }

    /** Original worker/root only. Completion runs in the physical job's finally, NOT on main.
     * The caller clears its Receipt pin there before separately delivering UI callbacks. */
    internal fun checkPhoneSkillSave(binding: PhoneSkillWrite.SaveBinding,
        publication: PhoneSkillBundleInstaller.Publication, onDone: (PhoneSkillInstallResult) -> Unit) {
        fun unverified(code: PhoneSkillBundleInstaller.Verification) =
            PhoneSkillInstallResult.BundleUnverified(binding.identity, publication, code)
        try { worker.execute {
            var result: PhoneSkillInstallResult = unverified(PhoneSkillBundleInstaller.Verification.VERIFICATION_UNAVAILABLE)
            try {
                val origin = binding.origin
                result = if (origin == null || !phoneSkillOriginCurrent(origin)) {
                    unverified(PhoneSkillBundleInstaller.Verification.ORIGIN_UNAVAILABLE)
                } else {
                    val identity = binding.identity
                    val read = PhoneSkillBundleReader.read(origin.root, identity.name, identity.revision, binding.descriptors)
                    when {
                        !phoneSkillOriginCurrent(origin) -> unverified(PhoneSkillBundleInstaller.Verification.ORIGIN_UNAVAILABLE)
                        read is PhoneSkillBundleReader.Read.Accepted && PhoneSkillBundleInstaller.matches(identity, read) ->
                            PhoneSkillInstallResult.BundleSaved(identity)
                        read is PhoneSkillBundleReader.Read.Rejected && read.reason == PhoneSkillBundleReader.Reason.IO ->
                            unverified(PhoneSkillBundleInstaller.Verification.VERIFICATION_UNAVAILABLE)
                        else -> unverified(PhoneSkillBundleInstaller.Verification.BUNDLE_INVALID)
                    }
                }
            } finally { onDone(result) }
        } } catch (_: java.util.concurrent.RejectedExecutionException) {
            onDone(unverified(PhoneSkillBundleInstaller.Verification.ORIGIN_UNAVAILABLE))
        }
    }

    internal fun attachManagedSkillOwner(): ManagedSkillOwner {
        val owner = ManagedSkillOwner()
        // Gate attachment and the last unretired real ready share a short lock.
        // Do not replay a phase/token observation across onReady or retirement.
        managedSkillGate.attach(owner)?.let { managedSkills.cancel(it) }
        return owner
    }

    internal fun detachManagedSkillOwner(owner: ManagedSkillOwner) {
        managedSkillGate.detach(owner)
        managedSkills.cancel(owner)
    }

    @Synchronized internal fun startProcess() {
        if (process != null || phase == Phase.INSTALLING || phase == Phase.STOPPING) return
        lastLaunch = null
        if (!installer.isCurrent()) {
            error = "runtime not installed"
            setPhase(Phase.ERROR)
            DshService.stopSelfIfRunning(app, runGen)
            return
        }
        baseUrl = null
        token = null
        error = null
        if (safeState != SafeState.OFF) {
            log("[dsh-app] safe mode is not available for the native engine; starting normal mode", "system")
            setSafeState(SafeState.OFF, null)
        }
        runSafe = false
        val gen = ++runGen
        readyAt = null
        healthyAt = null
        synchronized(runTail) { runTail.clear() }
        setPhase(Phase.STARTING)
        timeline.requested()
        worker.execute {
            var launched: DshProcess? = null
            try {
                // Phone control: start the Kotlin bridge. The native engine reaches it
                // through its own channel, not through guest files.
                PhoneControl.get(app).prepareLaunch(false) { log(it, "system") }
                if (!notedNativeLimits) {
                    notedNativeLimits = true
                    // The engine has no AGENTS.md loader and its tools are workspace-confined.
                    log("[dsh-app] visual replies: the native engine does not read a managed AGENTS.md; the setting has no effect", "system")
                    if (pendingPhoneStorage) {
                        log("[dsh-app] phone storage: native tools are confined to the workspace; /sdcard is not mounted", "system")
                    }
                }
                val env = LinkedHashMap<String, String>()
                env["TZ"] = java.util.TimeZone.getDefault().id
                env.putAll(pendingEnv)
                workspaceRecovery.applyEnvironment(env)
                // No Node/PRoot performance env is applied: this engine is native Go, and
                // NODE_OPTIONS/UV_THREADPOOL_SIZE would only be dead legacy wiring.
                bootProfile = try {
                    LastKnownGood.read(guestRoot)
                } catch (_: Exception) {
                    null
                }
                // startProcess advances runGen under this same monitor. Publish only while
                // this queued launch still owns that generation; once published, its non-null
                // process prevents another start from advancing the generation underneath it.
                val p = synchronized(this@RuntimeController) {
                    if (stopGen >= gen || gen != runGen) null
                    else DshProcess(
                        app, manifest,
                        object : DshProcess.Listener by this@RuntimeController {
                            override fun onLog(line: String, stream: String) {
                                if (stream != "system") {
                                    synchronized(runTail) {
                                        if (gen == runGen) {
                                            runTail.addLast(line)
                                            while (runTail.size > CrashClassifier.TAIL_LINES) runTail.removeFirst()
                                        }
                                    }
                                }
                                this@RuntimeController.onLog(line, stream)
                            }
                        },
                    ).also {
                        launched = it
                        lastLaunch = it.launchDiagnostics
                        process = it
                    }
                } ?: run {
                    PhoneControl.get(app).onEngineStopped()
                    return@execute
                }
                timeline.spawned()
                p.start(env)
            } catch (e: Throwable) {
                // Keep ownership while the old UID sweep runs, including a
                // failure after spawning but before the waiter was allocated.
                launched?.launchDiagnostics?.failed("startFailed")
                launched?.let { p -> p.failStart(e.message ?: e.javaClass.simpleName); p.awaitExit() }
                synchronized(this) {
                    if (gen != runGen) return@execute
                    process = null
                    PhoneControl.get(app).onEngineStopped()
                    val startupError = launched?.startupError
                    if (startupError == null && stopGen >= gen) {
                        // A cancelled preparation can throw before a waiter exists.
                        if (!resetting && phase == Phase.STOPPING) setPhase(Phase.INSTALLED)
                        return@execute
                    }
                    publishStartupFailure(startupError ?: e.message ?: e.javaClass.simpleName, ownerReleased = true)
                    log("[dsh-app] $error", "system")
                    if (!resetting) DshService.stopSelfIfRunning(app, gen)
                }
            }
        }
    }

    @Synchronized internal fun stopProcess(expectedGeneration: Int? = null): Boolean {
        // An automatic stop can arrive after a newer START service intent.
        // Check under the same monitor that advances runGen and retires the process.
        if (expectedGeneration != null && expectedGeneration != runGen) return false
        if (phase == Phase.INSTALLING) return false
        stopGen = runGen
        val p = process
        if (p == null) {
            if (phase == Phase.STARTING) {
                // The launch is still queued on the worker: finish the stop behind it.
                setPhase(Phase.STOPPING)
                worker.execute {
                    val launched = process
                    if (launched != null) launched.stop() else if (!resetting && phase == Phase.STOPPING) setPhase(Phase.INSTALLED)
                }
            } else if (!resetting && phase != Phase.NOT_INSTALLED && phase != Phase.ERROR) {
                // Keep ERROR: the service's own stop after a crash must not hide the failure.
                setPhase(Phase.INSTALLED)
            }
            return true
        }
        setPhase(Phase.STOPPING)
        p.stop()
        return true
    }

    /** The native engine resolves DNS itself; retained for the service's callback contract. */
    internal fun refreshDns(
        @Suppress("UNUSED_PARAMETER") watch: NetworkAccess.Watch,
        @Suppress("UNUSED_PARAMETER") properties: LinkProperties,
    ) = Unit

    /** The system blocked or restored this app's network (DshService's default network callback). */
    internal fun onNetworkBlocked(watch: NetworkAccess.Watch, blocked: Boolean, inForeground: Boolean) {
        val line = networkAccess.onBlocked(watch, blocked, inForeground) ?: return
        log(line, "system")
        emitStatus()
    }

    internal fun onNetworkWatchStarted() = networkAccess.startWatch()

    /** Retire only this registration; a late old service must not reset its replacement. */
    internal fun onNetworkWatchStopped(watch: NetworkAccess.Watch) = networkAccess.reset(watch)

    /** A line of the app's own into the runtime log. */
    internal fun note(line: String) = log(line, "system")

    /**
     * Stops DSH and waits for it to exit, then deletes the runtime with everything in /root except
     * [keep], which the next install puts back.
     */
    @Synchronized fun reset(keep: Set<ResetKeep> = emptySet(), onDone: (Throwable?) -> Unit) {
        stopGen = runGen
        resetting = true
        setPhase(Phase.STOPPING)
        worker.execute {
            try {
                process?.let { p ->
                    p.stop()
                    check(p.awaitExit(15_000)) { "runtime stop incomplete; retry reset after cleanup" }
                }
                check(process == null) { "runtime stop incomplete; retry reset after cleanup" }
                lastLaunch = null
                try {
                    check(runtimeLogs.pauseDisk()) { "log reset pause timed out" }
                    installer.reset(keep.flatMap { it.paths })
                } finally {
                    runtimeLogs.resumeDisk()
                }
                if (keep.isNotEmpty()) log("[dsh-app] reset keeps ${keep.joinToString { it.wire }}", "system")
                // The runtime is gone. Its safe-mode and failure record goes with it, in
                // memory first: the edit below drops the same keys from the preference
                // cache even when its commit, or the rollback's, fails.
                synchronized(this) {
                    // A fresh start: even kept plugins get a clean slate (auto safe mode still guards it).
                    strikes = 0
                    failure = null
                    mainFailure = null
                    safeState = SafeState.OFF
                    safeReason = null
                }
                workspaceRecovery.set(false) { next ->
                    val edit = prefs.edit().remove(K_SAFE_STATE).remove(K_SAFE_REASON).remove(K_STRIKES).remove(K_FAILURE)
                        .remove(K_MAIN_FAILURE).remove(K_MOVED)
                    if (next) edit.putBoolean(K_WORKSPACE_RECOVERY, true) else edit.remove(K_WORKSPACE_RECOVERY)
                    edit.commit()
                }
                synchronized(this) {
                    baseUrl = null
                    token = null
                    error = null
                    resetting = false
                    setPhase(Phase.NOT_INSTALLED)
                }
                main.post { onDone(null) }
            } catch (e: Throwable) {
                log("[dsh-app] reset failed: ${e.message}", "system")
                // Still stopping while the old process hasn't exited (its exit report moves the
                // phase on); otherwise the runtime is either still whole or gone.
                val installed = runCatching { installer.isCurrent() }.getOrDefault(false)
                synchronized(this) {
                    resetting = false
                    setPhase(when {
                        process != null -> Phase.STOPPING
                        installed -> Phase.INSTALLED
                        else -> Phase.NOT_INSTALLED
                    })
                }
                main.post { onDone(e) }
            }
        }
    }

    fun recentLogs(lines: Int): List<String> = runtimeLogs.recent(lines)
    fun logSnapshot(lines: Int): Map<String, Any?> = runtimeLogs.snapshot(lines).toMap()

    // ── Safe mode / last known good (called by RuntimePlugin) ───────────────────────

    /**
     * Always false: there is no rescue profile in the pinned native engine. Letting
     * the old policy auto-restart into "safe mode" would restart the same engine and
     * could loop forever. The UI switch stays for the channel contract only.
     */
    fun autoSafe(): Boolean = false

    fun setAutoSafe(enabled: Boolean) {
        prefs.edit().putBoolean(K_AUTO_SAFE, enabled).apply()
        emitStatus()
    }

    /** Hides the failure card; the strike count stays. */
    fun clearFailure() {
        failure = null
        prefs.edit().remove(K_FAILURE).apply()
        emitStatus()
    }

    /** Output around the failure on the card, else around the main profile's last failure (tokens masked). */
    fun failureLog(): List<String> {
        val name = when {
            failure != null -> LATEST_FAILURE_LOG
            mainFailure != null -> MAIN_FAILURE_LOG
            else -> return emptyList()
        }
        return try {
            File(logDir, name).readLines()
        } catch (_: Exception) {
            emptyList()
        }
    }

    /** What [restoreLastKnownGood] would change: `{available, at, disable, enable, changed, patchChanged, empty}`. */
    fun lastKnownGoodStatus(onDone: (Map<String, Any?>) -> Unit) {
        worker.execute {
            val result: Map<String, Any?> = try {
                val lkg = LastKnownGood.load(lkgFile)
                val current = LastKnownGood.read(guestRoot)
                if (lkg == null || current == null) {
                    mapOf("available" to false, "at" to lkg?.at)
                } else {
                    LkgPlan.of(lkg.snapshot, current).toMap() + mapOf("available" to true, "at" to lkg.at)
                }
            } catch (e: Exception) {
                mapOf("available" to false, "error" to e.message)
            }
            main.post { onDone(result) }
        }
    }

    /** Puts the main profile's bundle list and settings layer back to the last good run's. */
    fun restoreLastKnownGood(onDone: (Map<String, Any?>?, Throwable?) -> Unit) {
        worker.execute {
            try {
                checkRecoveryWrite(mainProfileOnly = true)
                val lkg = LastKnownGood.load(lkgFile) ?: throw IllegalStateException(AppStrings.get(app, R.string.safe_no_good_config))
                val plan = LastKnownGood.restore(guestRoot, lkg.snapshot, SafeMode.stamp(),
                    AppStrings.get(app, R.string.safe_config_missing), AppStrings.get(app, R.string.safe_config_busy))
                log(
                    "[dsh-app] restored the last good plugin set from ${SafeMode.formatTime(lkg.at)}: " +
                        "disabled ${plan.disable}, enabled ${plan.enable}, settings layer ${if (plan.patchChanged) "restored" else "unchanged"}",
                    "system",
                )
                main.post { onDone(plan.toMap(), null) }
            } catch (e: Throwable) {
                log("[dsh-app] restoring the last good plugin set failed: ${e.message}", "system")
                main.post { onDone(null, e) }
            }
        }
    }

    /** Home-level files that would also break the safe profile. */
    fun safePreflight(onDone: (List<Map<String, Any?>>) -> Unit) {
        worker.execute {
            val hazards = try {
                SafeMode.preflight(guestRoot, AppStrings.get(app, R.string.safe_patch_hazard)) { names ->
                    AppStrings.get(app, R.string.safe_env_hazard, names.joinToString(if (AppStrings.isEnglish(app)) ", " else "、"))
                }.map { it.toMap() }
            } catch (_: Exception) {
                emptyList()
            }
            main.post { onDone(hazards) }
        }
    }

    /** Renames the given preflight files to `.off-<time>`; the briefing tells the agent about it. */
    fun moveAside(paths: List<String>, onDone: (List<Map<String, Any?>>?, Throwable?) -> Unit) {
        worker.execute {
            try {
                checkRecoveryWrite(mainProfileOnly = false)
                val outcome = SafeMode.moveAside(guestRoot, paths, SafeMode.stamp())
                val moved = outcome.moved
                if (moved.isNotEmpty()) {
                    val record = JSONArray(movedAside() + moved.map { (from, to) -> "$from → $to" })
                    prefs.edit().putString(K_MOVED, record.toString()).apply()
                    moved.forEach { (from, to) -> log("[dsh-app] moved $from aside to $to", "system") }
                }
                outcome.failure?.let { throw it }
                main.post { onDone(moved.map { (from, to) -> mapOf("from" to from, "to" to to) }, null) }
            } catch (e: Throwable) {
                main.post { onDone(null, e) }
            }
        }
    }

    /** Worker-only: another physical launch or disk action cannot interleave with the write. */
    private fun checkRecoveryWrite(mainProfileOnly: Boolean) {
        val state = synchronized(this) {
            RuntimeRecoveryGate.State(phase, process != null, runSafe, resetting)
        }
        RuntimeRecoveryGate.check(state, mainProfileOnly) {
            // The native engine has no tracees to sweep; the state check is the gate.
            process == null
        }
    }

    private fun movedAside(): List<String> = try {
        val array = JSONArray(prefs.getString(K_MOVED, null) ?: "[]")
        List(array.length()) { array.getString(it) }
    } catch (_: Exception) {
        emptyList()
    }

    private fun setSafeState(next: SafeState, reason: String?) {
        safeState = next
        safeReason = if (next == SafeState.OFF) null else reason
        val edit = prefs.edit().putString(K_SAFE_STATE, next.wire).putString(K_SAFE_REASON, safeReason)
        if (next == SafeState.OFF) edit.remove(K_MOVED)
        edit.apply()
    }

    /** Called two minutes after the login line if the same run is still up. */
    private fun onHealthy() {
        healthyAt = null
        if (runSafe) return
        val recovered = safeState == SafeState.PROBATION
        strikes = 0
        failure = null
        mainFailure = null
        prefs.edit().putInt(K_STRIKES, 0).remove(K_FAILURE).remove(K_MAIN_FAILURE).apply()
        if (safeState != SafeState.OFF) setSafeState(SafeState.OFF, null)
        val booted = bootProfile
        worker.execute {
            try {
                if (LastKnownGood.pinBooted(booted) { LastKnownGood.save(lkgFile, it, System.currentTimeMillis()) }) {
                    log("[dsh-app] DSH has been up for 2 minutes; recorded its plugin set as the last good one", "system")
                }
            } catch (e: Exception) {
                log("[dsh-app] could not record the last good plugin set: ${e.message}", "system")
            }
        }
        if (recovered) notice(AppStrings.get(app, R.string.safe_normal_recovered))
        emitStatus()
    }

    /** Bundles enabled or upgraded since the last good run: the first suspects of a new failure. */
    private fun recentChanges(): List<String> = try {
        val lkg = LastKnownGood.load(lkgFile)
        val current = bootProfile ?: LastKnownGood.read(guestRoot)
        if (lkg == null || current == null) {
            emptyList()
        } else {
            val plan = LkgPlan.of(lkg.snapshot, current)
            (plan.disable + plan.changed).distinct()
        }
    } catch (_: Exception) {
        emptyList()
    }

    private fun recordFailure(f: RunFailure, tail: List<String>) {
        failure = f
        val json = JSONObject(f.toMap()).toString()
        val edit = prefs.edit().putString(K_FAILURE, json)
        // A later kill from outside says nothing about the profile: keep the plugin failure it followed.
        val main = !f.safeMode && (f.kind != FailureKind.KILLED || mainFailure == null)
        if (main) {
            mainFailure = f
            edit.putString(K_MAIN_FAILURE, json)
        }
        edit.apply()
        try {
            logDir.mkdirs()
            val text = tail.joinToString("\n", postfix = "\n") { CrashClassifier.redact(it) }
            File(logDir, LATEST_FAILURE_LOG).writeText(text)
            if (main) File(logDir, MAIN_FAILURE_LOG).writeText(text)
        } catch (_: Exception) {
        }
    }

    private fun readFailure(key: String): RunFailure? = try {
        prefs.getString(key, null)?.let { text ->
            val json = JSONObject(text)
            val kind = FailureKind.parse(json.optString("kind")) ?: return@let null
            fun list(name: String): List<String> {
                val array = json.optJSONArray(name) ?: return emptyList()
                return List(array.length()) { array.optString(it) }
            }
            RunFailure(
                kind = kind,
                exitCode = json.optInt("exitCode"),
                at = json.optLong("at"),
                safeMode = json.optBoolean("safeMode"),
                summary = if (json.isNull("summary")) null else json.optString("summary"),
                requiredRows = list("requiredRows"),
                suspects = list("suspects"),
                recent = list("recent"),
                diagnostics = if (json.isNull("diagnostics")) null else json.optString("diagnostics"),
                upSeconds = if (json.isNull("upSeconds")) null else json.optLong("upSeconds"),
            )
        }
    } catch (_: Exception) {
        null
    }

    private fun notice(text: String) = emit(mapOf("type" to "notice", "text" to text))

    // DshProcess.Listener

    override fun onLog(line: String, stream: String) {
        log(line, stream)
    }

    override fun onTidying(active: Boolean) {
        if (tidyingFiles == active) return
        tidyingFiles = active
        emitStatus()
    }

    override fun onStartupFailure(source: DshProcess) {
        // failStart holds the process monitor; stopProcess takes controller -> process.
        // Never take the controller monitor synchronously on that callback thread.
        main.post {
            synchronized(this) {
                if (source !== process) return@synchronized
                source.launchDiagnostics.failed("startFailed")
                publishStartupFailure(source.startupError, ownerReleased = false)
            }
        }
    }

    /** Local startup errors supersede only the latest card, not the main-profile history or strikes. */
    private fun publishStartupFailure(message: String?, ownerReleased: Boolean): Boolean {
        val next = StartupFailureState.of(message, ownerReleased, resetting) ?: return false
        error = next.error
        if (failure != null) {
            failure = null
            prefs.edit().remove(K_FAILURE).apply()
        }
        setPhase(next.phase)
        return true
    }

    @Synchronized override fun onReady(source: DshProcess, baseUrl: String, token: String) {
        // A late report from a stopped or replaced process.
        if (source !== process || phase == Phase.STOPPING || source.startupError != null ||
            stopGen >= runGen || resetting) return
        DshService.cancelStoppedAlert(app)
        this.baseUrl = baseUrl
        this.token = token
        if ((phase == Phase.STARTING || phase == Phase.RUNNING) &&
            stopGen < runGen && !resetting) {
            managedSkillGate.ready(runGen, token)
        }
        readyAt = SystemClock.elapsedRealtime()
        if (failure != null) {
            // This run got going, so the previous failure card is stale; strikes reset only when healthy.
            failure = null
            prefs.edit().remove(K_FAILURE).apply()
        }
        if (!runSafe) {
            // First boot creates the profile after startProcess reads it. Capture it before
            // RUNNING lets the app change it; a later disk read would not describe this boot.
            bootProfile = LastKnownGood.bootedAtReady(bootProfile) { LastKnownGood.read(guestRoot) }
        }
        if (!runSafe) healthyAt = System.currentTimeMillis() + SafePolicy.HEALTHY_MS
        log("[dsh-app] DSH is listening at $baseUrl${if (runSafe) " (safe mode)" else ""}", "system")
        timeline.ready()?.let { log(it, "system") }
        setPhase(Phase.RUNNING)
        PhoneControl.get(app).onEngineReady()
        val gen = runGen
        main.postDelayed({ if (gen == runGen && phase == Phase.RUNNING && process != null) onHealthy() }, SafePolicy.HEALTHY_MS)
    }

    @Synchronized override fun onExit(source: DshProcess, code: Int, expected: Boolean) {
        if (source !== process) return
        try {
            if (source.startupError != null) source.launchDiagnostics.failed("startFailed")
            else if (!expected && stopGen < runGen) source.launchDiagnostics.failed("exit:$code")
            process = null
            PhoneControl.get(app).onEngineStopped()
            baseUrl = null
            token = null
            healthyAt = null
            log("[dsh-app] DSH exited with code $code", "system")
            val tail = synchronized(runTail) { runTail.toList() }
            var f = CrashClassifier.classify(code, readyAt, SystemClock.elapsedRealtime(), System.currentTimeMillis(), tail, runSafe, source.direct)
            val startupError = source.startupError
            // A token deadline must not hide crash evidence already in the tail (#75); a silent
            // loader or a STOP that followed still ends as a plain startup failure.
            val classifyStartup = startupError != null && !expected && stopGen < runGen &&
                CrashClassifier.classifyAfterTokenTimeout(source.startupTokenTimedOut, f)
            if (!classifyStartup && publishStartupFailure(startupError, ownerReleased = true)) {
                // An accepted failure survives a later STOP. Reset still owns its final state.
                // Neither a deadline nor a local launch error is evidence against a plugin.
                if (!resetting) DshService.postStoppedAlert(app)
                DshService.stopSelfIfRunning(app, runGen)
                return
            }
            if (expected || stopGen >= runGen) {
                if (!resetting && phase == Phase.STOPPING) setPhase(Phase.INSTALLED)
                DshService.stopSelfIfRunning(app, runGen)
                return
            }
            if (SafePolicy.directLaunchFailed(f, source.direct)) {
                // Direct can't launch on this device: PRoot from now on with this runtime, no failure card,
                // no strike. A new runtime, or the user turning Direct on again, gives it another try.
                prefs.edit().putString(K_DIRECT_FAILED, manifest.runtimeVersion).apply()
                log("[dsh-app] direct launch failed (${f.summary}); starting again with compatible launch", "system")
                restartNow("with compatible launch")
                return
            }
            if (!runSafe) f = f.copy(recent = recentChanges())
            // There is no rescue profile in the native engine. Do not claim a safe
            // restart or show its notice; surface the failure and let the user start again.
            val outcome = SafePolicy.onFailure(safeState, strikes, f, autoSafe(),
                AppStrings.get(app, R.string.safe_probation_failed), AppStrings.get(app, R.string.safe_auto_started))
                .let { if (it.restartSafe) it.copy(state = SafeState.OFF, restartSafe = false, notice = null, reason = null) else it }
            val now = SystemClock.elapsedRealtime()
            val delay = SafePolicy.autoRestartDelay(f.kind, code, readyAt?.let { now - it }, autoRestarts.toList(), now)
            if (!outcome.restartSafe && delay != null && DshService.isRunning) {
                // Killed from outside after a good run (memory pressure, a phantom-process sweep): try again.
                autoRestarts.removeAll { now - it >= 600_000L }
                autoRestarts.addLast(now)
                val gen = runGen
                setPhase(Phase.STARTING)
                log("[dsh-app] killed from outside; restarting in ${delay / 1000}s", "system")
                main.postDelayed({
                    if (gen == runGen && stopGen < gen && phase == Phase.STARTING && process == null && DshService.isRunning) {
                        startProcess()
                    }
                }, delay)
                return
            }
            recordFailure(f, tail)
            strikes = outcome.strikes
            prefs.edit().putInt(K_STRIKES, strikes).apply()
            if (outcome.state != safeState) setSafeState(outcome.state, outcome.reason ?: safeReason)
            log("[dsh-app] classified as ${f.kind.wire}${if (f.safeMode) " (safe mode)" else ""}; consecutive failures: $strikes", "system")
            error = startupError?.let { "start failed: $it" } ?: "DSH exited unexpectedly (code $code)"
            if (outcome.restartSafe) {
                log("[dsh-app] restarting in safe mode", "system")
                outcome.notice?.let { notice(it) }
                restartNow("in safe mode")
            } else {
                setPhase(Phase.ERROR)
                DshService.postStoppedAlert(app)
                DshService.stopSelfIfRunning(app, runGen)
            }
        } finally {
            runtimeLogs.flush()
        }
    }

    /** Starts again right away; [startProcess] picks the mode. [how] names it if that fails. */
    private fun restartNow(how: String) {
        val gen = runGen
        main.post {
            if (gen != runGen || stopGen >= gen) return@post
            if (DshService.isRunning) {
                startProcess()
            } else {
                phase = Phase.INSTALLED
                try {
                    start(pendingEnv)
                } catch (e: Exception) {
                    log("[dsh-app] could not restart $how: ${e.message}", "system")
                    setPhase(Phase.ERROR)
                }
            }
        }
    }

    private fun log(line: String, stream: String) = runtimeLogs.accept(line, stream)

    private fun setPhase(next: Phase) {
        if (next != Phase.RUNNING) managedSkillGate.retire()
        phase = next
        emitStatus()
        DshService.updateNotification(app)
    }

    private fun emitStatus() = synchronized(statusPublishLock) {
        emit(mapOf("type" to "status", "status" to status()))
    }

    private fun emit(event: Map<String, Any?>) {
        val targets = synchronized(sinks) { sinks.toList() }
        if (targets.isEmpty()) return
        main.post { targets.forEach { it.emit(event) } }
    }

    companion object {
        private const val PREFS = "dsh_runtime"
        private const val K_SAFE_STATE = "safeState"
        private const val K_SAFE_REASON = "safeReason"
        private const val K_STRIKES = "strikes"
        private const val K_FAILURE = "failure"
        private const val K_MAIN_FAILURE = "mainFailure"
        private const val K_MOVED = "movedAside"
        private const val K_AUTO_SAFE = "autoSafe"
        private const val K_WORKSPACE_RECOVERY = "workspaceRecovery"
        private const val MAIN_FAILURE_LOG = "failure-normal.log"
        private const val LATEST_FAILURE_LOG = "failure-latest.log"

        @Volatile private var instance: RuntimeController? = null

        fun get(context: Context): RuntimeController =
            instance ?: synchronized(this) {
                instance ?: RuntimeController(context.applicationContext).also { instance = it }
            }
    }
}

/** The same accepted local failure while cleaning, after exit, or while reset still owns the disk. */
internal data class StartupFailureState(val error: String, val phase: RuntimeController.Phase) {
    companion object {
        fun of(message: String?, ownerReleased: Boolean, resetting: Boolean): StartupFailureState? {
            if (message == null) return null
            val phase = if (ownerReleased && !resetting) RuntimeController.Phase.ERROR
                else RuntimeController.Phase.STOPPING
            return StartupFailureState("start failed: $message", phase)
        }
    }
}

internal class WorkspaceRecoverySaveException(cause: Throwable? = null) :
    IllegalStateException("could not save workspace recovery mode; retry before starting", cause)

/** Worker-owned changes; status and launch use only the last successfully committed value. */
internal class WorkspaceRecoveryMode(initial: Boolean) {
    @Volatile var enabled: Boolean = initial
        private set

    fun set(next: Boolean, persist: (Boolean) -> Boolean) {
        val previous = enabled
        try {
            if (!persist(next)) throw WorkspaceRecoverySaveException()
        } catch (error: Exception) {
            // SharedPreferences updates its memory cache even when commit returns false.
            // Best-effort rollback avoids a later unrelated edit persisting that failed change.
            // A failed rollback still does not change this runtime owner's confirmed value.
            runCatching { persist(previous) }
            throw if (error is WorkspaceRecoverySaveException) error else WorkspaceRecoverySaveException(error)
        }
        enabled = next
    }

    fun applyEnvironment(environment: MutableMap<String, String>) {
        environment["DSH_APP_WORKSPACE_RECOVERY"] = if (enabled) "1" else "0"
    }
}
