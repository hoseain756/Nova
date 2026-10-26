package app.noor.mobile

import android.content.ComponentName
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Launcher aliases are the only owner of Android icon selection. */
internal object AppIconChannels {
    private val aliases = linkedMapOf(
        "classic" to "app.noor.mobile.IconDefault",
        "clear" to "app.noor.mobile.IconClear",
        "dark" to "app.noor.mobile.IconDark",
    )

    fun register(activity: FlutterActivity, messenger: BinaryMessenger) {
        val channel = MethodChannel(messenger, "nova/app_icon")
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "get" -> result.success(snapshot(activity))
                    "set" -> {
                        val choice = call.argument<String>("id")
                        if (choice !in aliases) {
                            result.error("invalid_icon", null, null)
                            return@setMethodCallHandler
                        }
                        val manager = activity.packageManager
                        val flags = PackageManager.DONT_KILL_APP
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            manager.setComponentEnabledSettings(aliases.map { (id, className) ->
                                PackageManager.ComponentEnabledSetting(
                                    ComponentName(activity, className),
                                    if (id == choice) PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                                    else PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                                    flags,
                                )
                            })
                        } else {
                            // Make the new entry available before hiding the old one.
                            manager.setComponentEnabledSetting(
                                ComponentName(activity, aliases.getValue(choice!!)),
                                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                                flags,
                            )
                            aliases.filterKeys { it != choice }.values.forEach { className ->
                                manager.setComponentEnabledSetting(
                                    ComponentName(activity, className),
                                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                                    flags,
                                )
                            }
                        }
                        result.success(snapshot(activity))
                    }
                    else -> result.notImplemented()
                }
            } catch (_: Exception) {
                result.error("icon_change_failed", null, null)
            }
        }
    }

    private fun snapshot(activity: FlutterActivity): Map<String, Any> {
        val manager = activity.packageManager
        val enabled = aliases.filter { (id, className) ->
            val state = manager.getComponentEnabledSetting(ComponentName(activity, className))
            state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED ||
                (id == "classic" && state == PackageManager.COMPONENT_ENABLED_STATE_DEFAULT)
        }.keys
        // Prefer an explicitly enabled alternate if a pre-Android-13 switch
        // was interrupted during its brief two-alias transition.
        val selected = enabled.firstOrNull { it != "classic" } ?: "classic"
        return mapOf("supported" to true, "selected" to selected, "ids" to aliases.keys.toList())
    }
}
