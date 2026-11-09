package io.github.ccch1mneyyy.dsh_app.pet

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.github.ccch1mneyyy.dsh_app.notify.LiveActivity

class PetOverlayPlugin : FlutterPlugin, ActivityAware {
    private lateinit var context: Context
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null

    private var engineBinding: FlutterPlugin.FlutterPluginBinding? = null
    private var producerToken: Long? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        if (::channel.isInitialized) channel.setMethodCallHandler(null)
        engineBinding = binding
        val currentChannel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel = currentChannel
        val assets = binding.flutterAssets
        PetOverlay.init(context) { path -> assets.getAssetFilePathByName(path) }
        var token = 0L
        token = PetOverlay.attachProducer(object : PetOverlay.Listener {
            override fun onStatus(status: Map<String, Any?>) {
                if (PetOverlay.ownsProducer(token)) currentChannel.invokeMethod("status", status)
            }

            override fun onOpenSettings() {
                if (PetOverlay.ownsProducer(token)) currentChannel.invokeMethod("openSettings", null)
            }

            override fun call(method: String, args: Any?, reply: (Any?) -> Unit) {
                if (!PetOverlay.ownsProducer(token)) return reply(null)
                currentChannel.invokeMethod(method, args, object : MethodChannel.Result {
                    override fun success(result: Any?) = reply(result)
                    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) = reply(null)
                    override fun notImplemented() = reply(null)
                })
            }
        })
        producerToken = token
        currentChannel.setMethodCallHandler { call, result ->
            if (!PetOverlay.ownsProducer(token)) {
                result.error("overlay_detached", "Pet overlay engine detached", null)
            } else {
                onMethodCall(call, result)
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        if (engineBinding !== binding) return
        channel.setMethodCallHandler(null)
        producerToken?.let(PetOverlay::detachProducer)
        producerToken = null
        engineBinding = null
        activity = null
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "push" -> {
                (call.arguments as? Map<*, *>)?.let(PetOverlay::push)
                result.success(null)
            }
            "reloadPack" -> {
                call.argument<String>("id")?.let { id ->
                    PetOverlay.reloadPack(id)
                    LiveActivity.forgetPack(context, id)
                }
                result.success(null)
            }
            "setEnabled" -> result.success(PetOverlay.setEnabled(call.argument<Boolean>("enabled") == true))
            "setAlwaysShow" -> result.success(PetOverlay.setAlwaysShow(call.argument<Boolean>("on") == true))
            "unsnooze" -> result.success(PetOverlay.unsnooze())
            "status" -> result.success(PetOverlay.status())
            "permissionStatus" -> result.success(PetOverlay.permissionStatus())
            "requestPermission" -> result.success(
                start(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:${context.packageName}"))) || openAppDetails(),
            )
            "openAppDetails" -> result.success(openAppDetails())
            else -> result.notImplemented()
        }
    }

    private fun openAppDetails() =
        start(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${context.packageName}")))

    /** From the activity when there is one (stays in the app's task), else as a new task. */
    private fun start(intent: Intent): Boolean = try {
        val a = activity
        if (a != null) a.startActivity(intent) else context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        true
    } catch (_: Exception) {
        false
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    companion object {
        const val CHANNEL = "dsh/pet_overlay"
    }
}
