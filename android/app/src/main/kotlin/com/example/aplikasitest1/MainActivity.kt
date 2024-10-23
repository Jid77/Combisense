package com.example.aplikasitest1

import io.flutter.embedding.android.FlutterActivity
import android.os.Bundle
import android.os.Environment
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Meminta izin penyimpanan saat aplikasi dijalankan
        if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.WRITE_EXTERNAL_STORAGE)
            != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(this, 
                arrayOf(android.Manifest.permission.WRITE_EXTERNAL_STORAGE), 
                1)
        }
    }
}
