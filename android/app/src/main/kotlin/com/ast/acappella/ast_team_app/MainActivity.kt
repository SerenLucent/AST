package com.ast.acappella.ast_team_app

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.ast.acappella/file_saver"
    private val saveRequestCode = 7042
    private var pendingResult: MethodChannel.Result? = null
    private var pendingBytes: ByteArray? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result -> handleMethodCall(call, result) }
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "saveFile") {
            result.notImplemented()
            return
        }
        if (pendingResult != null) {
            result.error("SAVE_IN_PROGRESS", "다른 파일을 저장하는 중입니다.", null)
            return
        }

        val fileName = call.argument<String>("fileName") ?: "score.pdf"
        val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
        val bytes = call.argument<ByteArray>("bytes")
        if (bytes == null) {
            result.error("MISSING_BYTES", "저장할 파일이 없습니다.", null)
            return
        }

        pendingResult = result
        pendingBytes = bytes
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mimeType
            putExtra(Intent.EXTRA_TITLE, fileName)
        }
        startActivityForResult(intent, saveRequestCode)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != saveRequestCode) return

        val result = pendingResult
        val bytes = pendingBytes
        pendingResult = null
        pendingBytes = null

        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result?.success(false)
            return
        }

        try {
            contentResolver.openOutputStream(data.data!!)?.use { output ->
                output.write(bytes)
                output.flush()
            } ?: throw IllegalStateException("저장 위치를 열 수 없습니다.")
            result?.success(true)
        } catch (error: Exception) {
            result?.error("SAVE_FAILED", error.message, null)
        }
    }
}
