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
        val intent = Intent(Intent.ACTION_GET_CONTENT)
        intent.type = "video/*"
        intent.addCategory(Intent.CATEGORY_OPENABLE)
        intent.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
        intent.putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("video/mp4", "video/avi", "video/mov", "video/mkv", "video/webm"))
        
        // Try to open in Videos category
        intent.putExtra("android.provider.extra.INITIAL_URI", MediaStore.Video.Media.EXTERNAL_CONTENT_URI)
        
        startActivityForResult(Intent.createChooser(intent, "Select Videos"), VIDEO_PICK_REQUEST_CODE)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        if (requestCode == VIDEO_PICK_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                val videoPaths = mutableListOf<String>()
                
                if (data.clipData != null) {
                    // Multiple files selected
                    val clipData = data.clipData!!
                    for (i in 0 until clipData.itemCount) {
                        val uri = clipData.getItemAt(i).uri
                        val path = getRealPathFromURI(uri)
                        if (path != null) {
                            videoPaths.add(path)
                        }
                    }
                } else if (data.data != null) {
                    // Single file selected
                    val path = getRealPathFromURI(data.data!!)
                    if (path != null) {
                        videoPaths.add(path)
                    }
                }
                
                if (videoPaths.isNotEmpty()) {
                    pendingResult?.success(videoPaths)
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