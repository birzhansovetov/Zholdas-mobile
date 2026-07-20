package com.example.zholdas

import android.app.Application
import com.example.zholdas.data.AppContainer
import com.example.zholdas.data.DefaultAppContainer
import com.example.zholdas.data.local.AppPreferences

class ZholdasApplication : Application() {
    lateinit var container: AppContainer
    lateinit var preferences: AppPreferences

    override fun onCreate() {
        super.onCreate()
        container = DefaultAppContainer(this)
        preferences = AppPreferences(this)
    }
}
