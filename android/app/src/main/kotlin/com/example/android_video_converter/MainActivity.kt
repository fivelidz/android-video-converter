package com.example.android_video_converter

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "video_converter/file_picker"
    private val VIDEO_PICK_REQUEST_CODE = 1001
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickVideoFromGallery" -> {
                    pendingResult = result
                    pickVideoFromGallery()
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun pickVideoFromGallery() {
        val intent = Intent(Intent.ACTION_PICK, MediaStore.Video.Media.EXTERNAL_CONTENT_URI)
        intent.type = "video/*"
        intent.putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("video/mp4", "video/avi", "video/mov", "video/mkv", "video/webm"))
        startActivityForResult(intent, VIDEO_PICK_REQUEST_CODE)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        if (requestCode == VIDEO_PICK_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                val videoUri: Uri? = data.data
                if (videoUri != null) {
                    val realPath = getRealPathFromURI(videoUri)
                    pendingResult?.success(realPath)
                } else {
                    pendingResult?.error("NO_VIDEO", "No video selected", null)
                }
            } else {
                pendingResult?.error("CANCELLED", "Video selection cancelled", null)
            }
            pendingResult = null
        }
    }

    private fun getRealPathFromURI(contentUri: Uri): String? {
        val cursor = contentResolver.query(contentUri, null, null, null, null)
        return if (cursor != null) {
            cursor.moveToFirst()
            val idx = cursor.getColumnIndex(MediaStore.Video.Media.DATA)
            val path = if (idx >= 0) cursor.getString(idx) else contentUri.path
            cursor.close()
            path
        } else {
            contentUri.path
        }
    }
}