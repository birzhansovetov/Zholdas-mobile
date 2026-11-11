package com.example.zholdas.ui.screens.map

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.view.Gravity
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.example.zholdas.data.local.localized
import com.example.zholdas.data.model.Event
import org.maplibre.android.MapLibre
import org.maplibre.android.annotations.IconFactory
import org.maplibre.android.annotations.MarkerOptions
import org.maplibre.android.camera.CameraPosition
import org.maplibre.android.camera.CameraUpdateFactory
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.maps.MapLibreMap
import org.maplibre.android.maps.MapView

/** Native OpenStreetMap renderer. No API key is required. */
internal class OpenMapController(context: Context) {
    val view: MapView
    private var map: MapLibreMap? = null
    private var events: List<Event> = emptyList()
    private var selectedId: Int? = null
    private var recommendedIds: Set<Int> = emptySet()
    private var onSelect: (Event) -> Unit = {}
    private val markerEvents = mutableMapOf<Long, Event>()
    private var userLocation: LatLng? = null
    private var userMarkerId: Long? = null
    private var styleUrl: String? = null
    var onCameraIdle: ((LatLng) -> Unit)? = null
    var error by mutableStateOf(false)
        private set

    init {
        MapLibre.getInstance(context)
        view = MapView(context).apply {
            onCreate(null)
            addOnDidFailLoadingMapListener { error = true }
            getMapAsync { readyMap ->
                map = readyMap
                readyMap.uiSettings.apply {
                    isLogoEnabled = false
                    isAttributionEnabled = true
                    attributionGravity = Gravity.BOTTOM or Gravity.START
                    isCompassEnabled = false
                }
                readyMap.cameraPosition = CameraPosition.Builder()
                    .target(LatLng(MapViewModel.DEFAULT_LATITUDE, MapViewModel.DEFAULT_LONGITUDE))
                    .zoom(12.0).build()
                readyMap.addOnCameraIdleListener {
                    readyMap.cameraPosition.target?.let { target ->
                        onCameraIdle?.invoke(target)
                    }
                }
                readyMap.setOnMarkerClickListener { marker ->
                    if (marker.id == userMarkerId) {
                        return@setOnMarkerClickListener true
                    }
                    markerEvents[marker.id]?.let(onSelect)
                    true
                }
                styleUrl?.let(::loadStyle)
            }
        }
    }

    fun updateStyle(dark: Boolean) {
        val next = "https://tiles.openfreemap.org/styles/" + if (dark) "dark" else "liberty"
        if (styleUrl != next) {
            styleUrl = next
            loadStyle(next)
        }
    }

    private fun loadStyle(url: String) {
        error = false
        map?.setStyle(url) {
            error = false
            renderMarkers()
        }
    }

    fun retry() { styleUrl?.let(::loadStyle) }

    fun updateUserLocation(location: LatLng?) {
        userLocation = location
        renderMarkers()
    }

    fun updateEvents(items: List<Event>, selected: Event?, recommended: Set<Int>, callback: (Event) -> Unit) {
        onSelect = callback
        if (items == events && selected?.id == selectedId && recommended == recommendedIds) return
        events = items
        selectedId = selected?.id
        recommendedIds = recommended
        renderMarkers()
    }

    private fun createUserLocationBitmap(): Bitmap {
        val density = view.resources.displayMetrics.density
        val size = (26 * density).toInt().coerceAtLeast(1)
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val center = size / 2f

        // White stroke border
        val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = android.graphics.Color.WHITE
        }
        canvas.drawCircle(center, center, 11 * density, strokePaint)

        // Blue filled circle (ZholdasAccent)
        val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = android.graphics.Color.rgb(37, 99, 235)
        }
        canvas.drawCircle(center, center, 8.5f * density, fillPaint)

        // Small white center dot for precision
        val dotPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = android.graphics.Color.WHITE
        }
        canvas.drawCircle(center, center, 2.5f * density, dotPaint)

        return bitmap
    }

    private fun renderMarkers() {
        val readyMap = map ?: return
        if (readyMap.style?.isFullyLoaded != true) return
        readyMap.removeAnnotations()
        markerEvents.clear()
        userMarkerId = null
        val density = view.resources.displayMetrics.density
        readyMap.uiSettings.setAttributionMargins(
            (8 * density).toInt(), 0, 0, ((if (selectedId == null) 8 else 230) * density).toInt()
        )
        events.filter { it.latitude.isFinite() && it.longitude.isFinite() &&
            it.latitude in -90.0..90.0 && it.longitude in -180.0..180.0 }.forEach { event ->
            val size = ((if (event.id == selectedId) 42 else 32) * density).toInt()
            val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            val paint = Paint(Paint.ANTI_ALIAS_FLAG)
            paint.color = android.graphics.Color.WHITE
            canvas.drawCircle(size / 2f, size / 2f, size / 2f, paint)
            paint.color = if (event.id in recommendedIds) android.graphics.Color.rgb(59, 130, 246)
                else getCategoryColor(event.category).toArgb()
            canvas.drawCircle(size / 2f, size / 2f, size / 2f - 2 * density, paint)
            paint.color = android.graphics.Color.WHITE
            canvas.drawCircle(size / 2f, size / 2f, 4 * density, paint)
            val marker = readyMap.addMarker(MarkerOptions()
                .position(LatLng(event.latitude, event.longitude))
                .title(event.title)
                .icon(IconFactory.getInstance(view.context).fromBitmap(bitmap)))
            markerEvents[marker.id] = event
        }

        userLocation?.let { loc ->
            if (loc.latitude.isFinite() && loc.longitude.isFinite() &&
                loc.latitude in -90.0..90.0 && loc.longitude in -180.0..180.0
            ) {
                val bitmap = createUserLocationBitmap()
                val marker = readyMap.addMarker(
                    MarkerOptions()
                        .position(loc)
                        .title("user_location")
                        .icon(IconFactory.getInstance(view.context).fromBitmap(bitmap))
                )
                userMarkerId = marker.id
            }
        }
    }

    fun moveTo(location: LatLng, zoom: Double = 13.0, animate: Boolean = true) {
        val update = CameraUpdateFactory.newLatLngZoom(location, zoom)
        if (animate) {
            map?.animateCamera(update)
        } else {
            map?.moveCamera(update)
        }
    }

    fun getCameraTarget(): LatLng? = map?.cameraPosition?.target

    fun recenter() {
        moveTo(LatLng(MapViewModel.DEFAULT_LATITUDE, MapViewModel.DEFAULT_LONGITUDE), 12.0)
    }
}

@Composable
internal fun OpenStreetMapView(
    controller: OpenMapController,
    events: List<Event>,
    selectedEvent: Event?,
    recommendedIds: Set<Int>,
    onSelectEvent: (Event) -> Unit,
    onCameraIdle: ((LatLng) -> Unit)? = null,
    modifier: Modifier = Modifier
) {
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    val dark = MaterialTheme.colorScheme.background.luminance() < 0.5f
    DisposableEffect(controller, lifecycle) {
        var started = false
        var resumed = false
        fun sync() {
            val shouldStart = lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)
            val shouldResume = lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED)
            if (!shouldResume && resumed) { controller.view.onPause(); resumed = false }
            if (!shouldStart && started) { controller.view.onStop(); started = false }
            if (shouldStart && !started) { controller.view.onStart(); started = true }
            if (shouldResume && !resumed) { controller.view.onResume(); resumed = true }
        }
        val observer = LifecycleEventObserver { _, _ -> sync() }
        lifecycle.addObserver(observer)
        sync()
        onDispose {
            lifecycle.removeObserver(observer)
            if (resumed) controller.view.onPause()
            if (started) controller.view.onStop()
            controller.view.onDestroy()
        }
    }
    LaunchedEffect(controller, dark) { controller.updateStyle(dark) }
    LaunchedEffect(controller, onCameraIdle) { controller.onCameraIdle = onCameraIdle }
    Box(modifier) {
        AndroidView(factory = { controller.view }, modifier = Modifier.matchParentSize(), update = {
            controller.updateEvents(events, selectedEvent, recommendedIds, onSelectEvent)
        })
        if (controller.error) {
            Surface(modifier = Modifier.align(Alignment.Center).padding(24.dp),
                onClick = controller::retry, color = MaterialTheme.colorScheme.errorContainer) {
                Text("map_tiles_error".localized, modifier = Modifier.padding(16.dp),
                    color = MaterialTheme.colorScheme.onErrorContainer)
            }
        }
    }
}