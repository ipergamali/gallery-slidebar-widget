package com.example.photowidget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import androidx.documentfile.provider.DocumentFile
import com.example.photowidget.data.WidgetPreferences
import kotlinx.coroutines.runBlocking
import java.util.Locale

class PhotoWidgetService : RemoteViewsService() {
    companion object {
        private const val MAX_ITEMS = 60
    }

    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        val appWidgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        return PhotoWidgetFactory(applicationContext, appWidgetId)
    }
}

private class PhotoWidgetFactory(
    private val context: Context,
    private val appWidgetId: Int
) : RemoteViewsService.RemoteViewsFactory {

    private val imageUris = mutableListOf<Uri>()

    override fun onCreate() {
        loadImages()
    }

    override fun onDataSetChanged() {
        loadImages()
    }

    override fun onDestroy() {
        imageUris.clear()
    }

    override fun getCount(): Int = imageUris.size

    override fun getViewAt(position: Int): RemoteViews? {
        if (position < 0 || position >= imageUris.size) return null
        val uri = imageUris[position]
        val bitmap = decodeForWidget(uri)
        return RemoteViews(context.packageName, R.layout.widget_photo_item).apply {
            if (bitmap != null) {
                setImageViewBitmap(R.id.imageItem, bitmap)
            } else {
                setImageViewResource(R.id.imageItem, android.R.drawable.ic_menu_report_image)
            }
        }
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = true

    private fun loadImages() {
        imageUris.clear()
        val folderUri = runBlocking {
            WidgetPreferences.getFolder(context, appWidgetId)
        } ?: return
        val documentFile = DocumentFile.fromTreeUri(context, folderUri) ?: return
        val files = try {
            documentFile.listFiles()
                .filter { it.isReadableImage() }
                .sortedBy { it.name ?: "" }
                .take(MAX_ITEMS)
        } catch (_: SecurityException) {
            emptyList()
        }
        files.forEach { file ->
            imageUris.add(file.uri)
        }
    }

    private fun DocumentFile.isReadableImage(): Boolean {
        if (!isFile) return false
        val mimeType = type
        if (mimeType != null && mimeType.startsWith("image/")) {
            return true
        }
        val fileName = name?.lowercase(Locale.getDefault()) ?: return false
        return fileName.endsWith(".jpg") ||
            fileName.endsWith(".jpeg") ||
            fileName.endsWith(".png") ||
            fileName.endsWith(".gif") ||
            fileName.endsWith(".webp") ||
            fileName.endsWith(".bmp")
    }

    private fun decodeForWidget(uri: Uri): Bitmap? {
        val resolver = context.contentResolver
        val firstOptions = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        resolver.openInputStream(uri)?.use { stream ->
            BitmapFactory.decodeStream(stream, null, firstOptions)
        }
        if (firstOptions.outWidth <= 0 || firstOptions.outHeight <= 0) {
            return null
        }
        val targetWidth = 600
        val targetHeight = 600
        val sampleSize = calculateInSampleSize(firstOptions.outWidth, firstOptions.outHeight, targetWidth, targetHeight)
        val finalOptions = BitmapFactory.Options().apply { inSampleSize = sampleSize }
        resolver.openInputStream(uri)?.use { stream ->
            return BitmapFactory.decodeStream(stream, null, finalOptions)
        }
        return null
    }

    private fun calculateInSampleSize(width: Int, height: Int, reqWidth: Int, reqHeight: Int): Int {
        var inSampleSize = 1
        if (height > reqHeight || width > reqWidth) {
            var halfHeight = height / 2
            var halfWidth = width / 2
            while (halfHeight / inSampleSize >= reqHeight && halfWidth / inSampleSize >= reqWidth) {
                inSampleSize *= 2
            }
        }
        return inSampleSize
    }
}
