package io.github.ccch1mneyyy.dsh_app.pet

import io.github.ccch1mneyyy.dsh_app.i18n.AppStrings
import io.github.ccch1mneyyy.dsh_app.R
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.util.Log

internal object PetOverlayProbe {
    const val ACTION = "io.github.ccch1mneyyy.dsh_app.PET_PROBE"

    fun register(context: Context) {
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(c: Context, intent: Intent) {
                when (intent.getStringExtra("cmd")) {
                    "push" -> PetOverlay.push(
                        mapOf(
                            "packId" to (intent.getStringExtra("pet") ?: "whale-girl"),
                            "state" to (intent.getStringExtra("state") ?: "idle"),
                            "tier" to intent.getIntExtra("tier", 0),
                            "sessionId" to intent.getStringExtra("session"),
                            "host" to intent.getStringExtra("host"),
                            "active" to (if (intent.hasExtra("active")) intent.getBooleanExtra("active", false) else null),
                            "size" to (intent.getStringExtra("size") ?: "medium"),
                            "bubble" to intent.getStringExtra("bubble")?.let { text ->
                                mapOf(
                                    "id" to (intent.getStringExtra("bubbleId") ?: "probe-${System.nanoTime()}"),
                                    "kind" to (intent.getStringExtra("kind") ?: "done"),
                                    "text" to text,
                                    "title" to intent.getStringExtra("title"),
                                    "sessionId" to intent.getStringExtra("session"),
                                    "host" to intent.getStringExtra("host"),
                                    "untilMs" to System.currentTimeMillis() + intent.getLongExtra("ttl", PetPush.DEFAULT_BUBBLE_MS),
                                    "detail" to intent.getStringExtra("detail"),
                                    "ask" to intent.getStringExtra("askText")?.let { askText ->
                                        mapOf(
                                            "eventId" to (intent.getStringExtra("eventId") ?: "probe-event"),
                                            "token" to intent.getLongExtra("requestToken", -1L),
                                            "kind" to (intent.getStringExtra("askKind") ?: "approval"),
                                            "text" to askText,
                                            "approvable" to intent.getBooleanExtra("approvable", false),
                                            "choices" to intent.getStringExtra("choices")?.split('|'),
                                        )
                                    },
                                )
                            },
                            "canStop" to intent.getBooleanExtra("canStop", false),
                            "hosts" to intent.getStringExtra("hosts")?.split('|')?.mapIndexed { i, label ->
                                mapOf("ref" to "probe-$i", "label" to label, "current" to (i == 0))
                            },
                        ),
                    )
                    "ask" -> PetOverlay.probeAsk(intent.getBooleanExtra("fresh", false))
                    "enable" -> PetOverlay.setEnabled(intent.getBooleanExtra("on", true))
                    "always" -> PetOverlay.setAlwaysShow(intent.getBooleanExtra("on", true))
                    "unsnooze" -> PetOverlay.unsnooze()
                    "permission" -> PetOverlay.permissionStatus()
                    // A chat notification as Dart posts it, to check ResultSilence with `dumpsys notification`.
                    "notify" -> io.github.ccch1mneyyy.dsh_app.notify.ChatNotifier(c.applicationContext).show(
                        io.github.ccch1mneyyy.dsh_app.notify.ChatNotifier.Post(
                            group = "probe|s1", key = intent.getStringExtra("key") ?: "turn",
                            attention = intent.getBooleanExtra("attention", false),
                            title = AppStrings.get(context, R.string.pet_probe_title), text = intent.getStringExtra("text") ?: AppStrings.get(context, R.string.pet_probe_done), publicText = AppStrings.get(context, R.string.pet_probe_public),
                            sessionId = "s1", host = "{\"kind\":\"local\",\"id\":\"local\"}", kind = "done", eventId = null,
                        ),
                    )
                    else -> PetOverlay.evaluate()
                }
                Log.i("DshPet", "probe ${PetOverlay.debugState()} status=${PetOverlay.status()}")
            }
        }
        val filter = IntentFilter(ACTION)
        // Exported so adb's shell can reach it; debuggable builds only.
        if (Build.VERSION.SDK_INT >= 33) context.registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED) else context.registerReceiver(receiver, filter)
    }
}
