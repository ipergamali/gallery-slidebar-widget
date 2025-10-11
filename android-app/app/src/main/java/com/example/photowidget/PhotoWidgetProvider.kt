package com.example.photowidget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import com.example.photowidget.config.PhotoWidgetConfigActivity
import com.example.photowidget.data.WidgetPreferences
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class PhotoWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        appWidgetIds.forEach { appWidgetId ->
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        val scope = CoroutineScope(Dispatchers.IO)
        appWidgetIds.forEach { appWidgetId ->
            scope.launch { WidgetPreferences.clearFolder(context, appWidgetId) }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_REFRESH) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val requestedId = intent.getIntExtra(
                AppWidgetManager.EXTRA_APPWIDGET_ID,
                AppWidgetManager.INVALID_APPWIDGET_ID
            )
            if (requestedId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                appWidgetManager.notifyAppWidgetViewDataChanged(requestedId, R.id.imageFlipper)
            } else {
                val ids = appWidgetManager.getAppWidgetIds(
                    ComponentName(context, PhotoWidgetProvider::class.java)
                )
                ids.forEach { appWidgetId ->
                    appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.imageFlipper)
                }
            }
        }
    }

    companion object {
        private const val ACTION_REFRESH = "com.example.photowidget.action.REFRESH"

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val views = RemoteViews(context.packageName, R.layout.widget_photo_flipper).apply {
                val serviceIntent = Intent(context, PhotoWidgetService::class.java).apply {
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                    data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
                }
                setRemoteAdapter(R.id.imageFlipper, serviceIntent)
                setEmptyView(R.id.imageFlipper, R.id.emptyView)

                val configIntent = Intent(context, PhotoWidgetConfigActivity::class.java).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_CONFIGURE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                }

                val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    appWidgetId,
                    configIntent,
                    flags
                )
                setOnClickPendingIntent(R.id.widgetRoot, pendingIntent)

                val refreshIntent = Intent(context, PhotoWidgetProvider::class.java).apply {
                    action = ACTION_REFRESH
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                }
                val refreshFlags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                val refreshPendingIntent = PendingIntent.getBroadcast(
                    context,
                    appWidgetId,
                    refreshIntent,
                    refreshFlags
                )
                setOnClickPendingIntent(R.id.refreshButton, refreshPendingIntent)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.imageFlipper)
        }

        fun requestFullRefresh(context: Context) {
            val intent = Intent(context, PhotoWidgetProvider::class.java).apply {
                action = ACTION_REFRESH
            }
            val flags = PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            val pendingIntent = PendingIntent.getBroadcast(context, 0, intent, flags)
            try {
                pendingIntent.send()
            } catch (ignored: PendingIntent.CanceledException) {
            }
        }
    }
}
