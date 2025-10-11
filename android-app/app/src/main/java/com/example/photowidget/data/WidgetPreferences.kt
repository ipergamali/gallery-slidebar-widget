package com.example.photowidget.data

import android.content.Context
import android.net.Uri
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.first

object WidgetPreferences {
    private val Context.dataStore by preferencesDataStore(name = "photo_widget")

    private fun folderKey(appWidgetId: Int) = stringPreferencesKey("folder_uri_$appWidgetId")

    suspend fun setFolder(context: Context, appWidgetId: Int, uri: Uri?) {
        context.dataStore.edit { prefs ->
            val key = folderKey(appWidgetId)
            if (uri == null) {
                prefs.remove(key)
            } else {
                prefs[key] = uri.toString()
            }
        }
    }

    suspend fun getFolder(context: Context, appWidgetId: Int): Uri? {
        val key = folderKey(appWidgetId)
        val prefs = context.dataStore.data.first()
        val stored = prefs[key] ?: return null
        return Uri.parse(stored)
    }

    suspend fun clearFolder(context: Context, appWidgetId: Int) {
        setFolder(context, appWidgetId, null)
    }
}
