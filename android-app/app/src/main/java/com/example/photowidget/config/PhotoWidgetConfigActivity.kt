package com.example.photowidget.config

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.result.contract.ActivityResultContracts
import androidx.lifecycle.lifecycleScope
import com.example.photowidget.PhotoWidgetProvider
import com.example.photowidget.R
import com.example.photowidget.data.WidgetPreferences
import kotlinx.coroutines.launch

class PhotoWidgetConfigActivity : ComponentActivity() {

    private var appWidgetId: Int = AppWidgetManager.INVALID_APPWIDGET_ID

    private val folderPicker = registerForActivityResult(ActivityResultContracts.OpenDocumentTree()) { uri ->
        if (uri != null) {
            onFolderSelected(uri)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_photo_widget_config)

        setResult(Activity.RESULT_CANCELED)

        appWidgetId = intent?.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
            ?: AppWidgetManager.INVALID_APPWIDGET_ID

        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        findViewById<android.widget.Button>(R.id.pickFolderButton).setOnClickListener {
            folderPicker.launch(null)
        }
    }

    private fun onFolderSelected(uri: Uri) {
        try {
            contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION
            )
        } catch (_: SecurityException) {
        }
        lifecycleScope.launch {
            WidgetPreferences.setFolder(this@PhotoWidgetConfigActivity, appWidgetId, uri)
            val appWidgetManager = AppWidgetManager.getInstance(this@PhotoWidgetConfigActivity)
            PhotoWidgetProvider.updateAppWidget(
                this@PhotoWidgetConfigActivity,
                appWidgetManager,
                appWidgetId
            )
            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.imageFlipper)
            val resultValue = Intent().apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            }
            setResult(Activity.RESULT_OK, resultValue)
            finish()
        }
    }
}
