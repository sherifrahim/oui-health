package health.oui.app

import android.os.Bundle
import android.view.Gravity
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.activity.ComponentActivity
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.launch

/**
 * Minimal reader UI: checks Health Connect, asks for the watch health permissions, then shows a
 * summary of the last 24h. No Samsung code, no un-gating — the official pipeline (finding 0004).
 */
class MainActivity : ComponentActivity() {

    private lateinit var repo: HealthRepo
    private lateinit var output: TextView

    private val requestPerms =
        registerForActivityResult(PermissionController.createRequestPermissionResultContract()) { granted ->
            if (granted.containsAll(repo.readPermissions)) load()
            else output.text = "Some permissions were not granted:\n" +
                (repo.readPermissions - granted).joinToString("\n")
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        repo = HealthRepo(this)

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(32, 48, 32, 32)
        }
        val title = TextView(this).apply {
            text = "oui-health — watch data on any Android"
            textSize = 20f
            gravity = Gravity.CENTER
        }
        val refresh = Button(this).apply {
            text = "Read my watch health data"
            setOnClickListener { start() }
        }
        output = TextView(this).apply { text = "Tap the button to begin.\n"; textSize = 14f }
        root.addView(title)
        root.addView(refresh)
        root.addView(ScrollView(this).apply { addView(output) })
        setContentView(root)
    }

    private fun start() {
        when (HealthConnectClient.getSdkStatus(this)) {
            HealthConnectClient.SDK_UNAVAILABLE ->
                output.text = "Health Connect is not available on this device."
            HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED ->
                output.text = "Update Health Connect (Play Store) and retry."
            else -> ensurePermissionsThenLoad()
        }
    }

    private fun ensurePermissionsThenLoad() = lifecycleScope.launch {
        val granted = repo.grantedPermissions()
        if (granted.containsAll(repo.readPermissions)) load() else requestPerms.launch(repo.readPermissions)
    }

    private fun load() = lifecycleScope.launch {
        output.text = "Reading…"
        output.text = try { repo.summarize() } catch (e: Exception) { "Error: ${e.message}" }
    }
}
