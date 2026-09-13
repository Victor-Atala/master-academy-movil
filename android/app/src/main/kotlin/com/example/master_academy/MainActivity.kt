package com.example.master_academy

import android.app.Activity
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.masteracademy.app/file_downloader"
    private val CREATE_DOCUMENT_REQUEST = 5050
    private var pendingResult: MethodChannel.Result? = null
    private var pendingFileBytes: ByteArray? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openFileManagerToSave", "downloadToPublicFolder" -> {
                    val fileName = call.argument<String>("fileName") ?: "documento.pdf"
                    val fileBytes = call.argument<ByteArray>("bytes")
                    val mimeType = (call.argument<String>("mimeType") ?: "application/pdf").lowercase().trim()

                    if (fileBytes == null) {
                        result.error("NO_DATA", "No se recibieron bytes del archivo", null)
                        return@setMethodCallHandler
                    }

                    if (pendingResult != null) {
                        result.error("ALREADY_ACTIVE", "Ya hay una operación de guardado en curso", null)
                        return@setMethodCallHandler
                    }

                    pendingResult = result
                    pendingFileBytes = fileBytes

                    try {
                        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = mimeType
                            putExtra(Intent.EXTRA_TITLE, fileName)
                        }
                        startActivityForResult(intent, CREATE_DOCUMENT_REQUEST)
                    } catch (e: Exception) {
                        pendingResult = null
                        pendingFileBytes = null
                        result.error("CREATE_DOCUMENT_FAILED", e.message, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == CREATE_DOCUMENT_REQUEST) {
            val currentResult = pendingResult
            val bytes = pendingFileBytes
            pendingResult = null
            pendingFileBytes = null

            if (resultCode == Activity.RESULT_OK && data?.data != null) {
                val uri: Uri = data.data!!
                try {
                    contentResolver.openOutputStream(uri)?.use { outputStream ->
                        if (bytes != null) {
                            outputStream.write(bytes)
                            outputStream.flush()
                        }
                    }
                    currentResult?.success(uri.toString())
                } catch (e: Exception) {
                    currentResult?.error("WRITE_ERROR", e.message, null)
                }
            } else {
                // El usuario canceló o cerró el explorador de archivos
                currentResult?.success("CANCELLED")
            }
        }
    }
}

