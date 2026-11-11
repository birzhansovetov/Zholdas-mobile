package com.example.zholdas.ui.screens.events

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.location.Geocoder
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.view.Gravity
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.MyLocation
import androidx.compose.material.icons.filled.Place
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.example.zholdas.data.local.localized
import com.example.zholdas.theme.*
import com.example.zholdas.ui.components.ModernCard
import com.example.zholdas.ui.components.PrimaryButton
import com.google.android.gms.location.LocationServices
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.maplibre.android.MapLibre
import org.maplibre.android.annotations.IconFactory
import org.maplibre.android.annotations.Marker
import org.maplibre.android.annotations.MarkerOptions
import org.maplibre.android.camera.CameraPosition
import org.maplibre.android.camera.CameraUpdateFactory
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.maps.MapLibreMap
import org.maplibre.android.maps.MapView
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EventLocationPickerDialog(
    initialLatitude: Double,
    initialLongitude: Double,
    initialLocationName: String,
    onDismiss: () -> Unit,
    onConfirm: (latitude: Double, longitude: Double, locationName: String) -> Unit
) {
    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    val dark = MaterialTheme.colorScheme.background.luminance() < 0.5f

    var draftLatitude by remember { mutableDoubleStateOf(initialLatitude) }
    var draftLongitude by remember { mutableDoubleStateOf(initialLongitude) }
    var draftLocationName by remember { mutableStateOf(initialLocationName) }
    var isResolvingLocation by remember { mutableStateOf(false) }

    var mapInstance by remember { mutableStateOf<MapLibreMap?>(null) }
    var markerRef by remember { mutableStateOf<Marker?>(null) }
    var isMapConfigured by remember { mutableStateOf(false) }

    fun resolveAddress(lat: Double, lon: Double) {
        coroutineScope.launch {
            isResolvingLocation = true
            val addressText = withContext(Dispatchers.IO) {
                try {
                    if (Geocoder.isPresent()) {
                        val geocoder = Geocoder(context, Locale.getDefault())
                        @Suppress("DEPRECATION")
                        val list = geocoder.getFromLocation(lat, lon, 1)
                        val item = list?.firstOrNull()
                        listOfNotNull(
                            item?.thoroughfare,
                            item?.subThoroughfare,
                            item?.featureName,
                            item?.subLocality,
                            item?.locality
                        ).filter { it.isNotBlank() }
                            .distinct()
                            .joinToString(", ")
                            .ifBlank { null }
                    } else null
                } catch (_: Exception) {
                    null
                }
            }
            isResolvingLocation = false
            if (!addressText.isNullOrBlank()) {
                draftLocationName = addressText
            }
        }
    }

    val permissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestMultiplePermissions()
    ) { permissions ->
        val fineGranted = permissions[Manifest.permission.ACCESS_FINE_LOCATION] == true
        val coarseGranted = permissions[Manifest.permission.ACCESS_COARSE_LOCATION] == true
        if (fineGranted || coarseGranted) {
            locateUser(context, mapInstance, markerRef) { lat, lon ->
                draftLatitude = lat
                draftLongitude = lon
                resolveAddress(lat, lon)
            }
        } else {
            Toast.makeText(context, "map_location_denied".localized, Toast.LENGTH_SHORT).show()
        }
    }

    fun requestMyLocation() {
        val fine = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        val coarse = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
        if (fine || coarse) {
            locateUser(context, mapInstance, markerRef) { lat, lon ->
                draftLatitude = lat
                draftLongitude = lon
                resolveAddress(lat, lon)
            }
        } else {
            permissionLauncher.launch(
                arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION)
            )
        }
    }

    val mapView = remember(context) {
        MapLibre.getInstance(context)
        MapView(context).apply {
            onCreate(null)
        }
    }

    DisposableEffect(mapView, lifecycle) {
        var started = false
        var resumed = false
        fun sync() {
            val shouldStart = lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)
            val shouldResume = lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED)
            if (!shouldResume && resumed) { mapView.onPause(); resumed = false }
            if (!shouldStart && started) { mapView.onStop(); started = false }
            if (shouldStart && !started) { mapView.onStart(); started = true }
            if (shouldResume && !resumed) { mapView.onResume(); resumed = true }
        }
        val observer = LifecycleEventObserver { _, _ -> sync() }
        lifecycle.addObserver(observer)
        sync()
        onDispose {
            lifecycle.removeObserver(observer)
            if (resumed) mapView.onPause()
            if (started) mapView.onStop()
            mapView.onDestroy()
        }
    }

    LaunchedEffect(mapView) {
        mapView.getMapAsync { readyMap ->
            mapInstance = readyMap
        }
    }

    LaunchedEffect(dark, mapInstance) {
        val readyMap = mapInstance ?: return@LaunchedEffect

        if (!isMapConfigured) {
            readyMap.uiSettings.apply {
                isLogoEnabled = false
                isAttributionEnabled = true
                attributionGravity = Gravity.BOTTOM or Gravity.START
                isCompassEnabled = false
            }
            val density = context.resources.displayMetrics.density
            readyMap.uiSettings.setAttributionMargins(
                (8 * density).toInt(), 0, 0, (210 * density).toInt()
            )

            val initialPos = LatLng(draftLatitude, draftLongitude)
            readyMap.cameraPosition = CameraPosition.Builder()
                .target(initialPos)
                .zoom(14.0)
                .build()

            readyMap.addOnMapClickListener { clickedLatLng ->
                markerRef?.position = clickedLatLng
                draftLatitude = clickedLatLng.latitude
                draftLongitude = clickedLatLng.longitude
                resolveAddress(clickedLatLng.latitude, clickedLatLng.longitude)
                true
            }
            isMapConfigured = true
        }

        val styleUrl = "https://tiles.openfreemap.org/styles/" + if (dark) "dark" else "liberty"
        if (readyMap.style?.url != styleUrl) {
            readyMap.setStyle(styleUrl) {
                readyMap.removeAnnotations()
                val markerIcon = IconFactory.getInstance(context).fromBitmap(createPickerMarkerBitmap(context))
                val currentPos = LatLng(draftLatitude, draftLongitude)
                val marker = readyMap.addMarker(
                    MarkerOptions()
                        .position(currentPos)
                        .icon(markerIcon)
                )
                markerRef = marker

                if (draftLocationName.isBlank()) {
                    resolveAddress(draftLatitude, draftLongitude)
                }
            }
        }
    }

    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false)
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(ZholdasBackground)
        ) {
            // Map
            AndroidView(
                factory = { mapView },
                modifier = Modifier.fillMaxSize()
            )

            // Top Bar
            TopAppBar(
                title = {
                    Text(
                        text = "create_ev_pick_location".localized,
                        color = ZholdasTextPrimary,
                        fontWeight = FontWeight.Bold,
                        fontSize = 18.sp
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onDismiss) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "create_ev_cancel".localized,
                            tint = ZholdasTextPrimary
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = ZholdasElevatedSurface.copy(alpha = 0.95f)
                ),
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .statusBarsPadding()
            )

            // My Location FAB
            FloatingActionButton(
                onClick = { requestMyLocation() },
                containerColor = ZholdasElevatedSurface,
                contentColor = ZholdasAccent,
                shape = CircleShape,
                modifier = Modifier
                    .align(Alignment.BottomEnd)
                    .padding(end = 16.dp, bottom = 220.dp)
                    .size(48.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.MyLocation,
                    contentDescription = "create_ev_my_location".localized,
                    tint = ZholdasAccent
                )
            }

            // Bottom Selection Card
            ModernCard(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .fillMaxWidth()
                    .padding(16.dp)
                    .navigationBarsPadding()
            ) {
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        Box(
                            modifier = Modifier
                                .size(36.dp)
                                .background(ZholdasAccent.copy(alpha = 0.15f), CircleShape),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                imageVector = Icons.Default.Place,
                                contentDescription = null,
                                tint = ZholdasAccent,
                                modifier = Modifier.size(20.dp)
                            )
                        }
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = if (isResolvingLocation && draftLocationName.isBlank()) {
                                    "..."
                                } else if (draftLocationName.isNotBlank()) {
                                    draftLocationName
                                } else {
                                    "create_ev_selected_point_name".localized
                                },
                                color = ZholdasTextPrimary,
                                fontWeight = FontWeight.Bold,
                                fontSize = 15.sp,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                            Text(
                                text = String.format(Locale.US, "%.5f, %.5f", draftLatitude, draftLongitude),
                                color = ZholdasTextSecondary,
                                fontSize = 12.sp
                            )
                        }
                    }

                    Text(
                        text = "create_ev_map_tap_hint".localized,
                        color = ZholdasTextSecondary,
                        fontSize = 12.sp
                    )

                    PrimaryButton(
                        text = "create_ev_confirm_location".localized,
                        onClick = {
                            val resolvedName = draftLocationName.trim()
                            val finalName = if (resolvedName.isNotEmpty()) {
                                resolvedName
                            } else {
                                initialLocationName.trim().ifEmpty { "create_ev_selected_point_name".localized }
                            }
                            onConfirm(draftLatitude, draftLongitude, finalName)
                        }
                    )
                }
            }
        }
    }
}

private fun locateUser(
    context: Context,
    map: MapLibreMap?,
    marker: Marker?,
    onLocationFound: (lat: Double, lon: Double) -> Unit
) {
    try {
        val fused = LocationServices.getFusedLocationProviderClient(context)
        fused.lastLocation.addOnSuccessListener { loc: Location? ->
            if (loc != null) {
                val latLng = LatLng(loc.latitude, loc.longitude)
                marker?.position = latLng
                map?.animateCamera(CameraUpdateFactory.newLatLngZoom(latLng, 15.0))
                onLocationFound(loc.latitude, loc.longitude)
            } else {
                val lm = context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
                val fallback = lm?.getLastKnownLocation(LocationManager.GPS_PROVIDER)
                    ?: lm?.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)
                if (fallback != null) {
                    val latLng = LatLng(fallback.latitude, fallback.longitude)
                    marker?.position = latLng
                    map?.animateCamera(CameraUpdateFactory.newLatLngZoom(latLng, 15.0))
                    onLocationFound(fallback.latitude, fallback.longitude)
                } else {
                    Toast.makeText(context, "map_location_denied".localized, Toast.LENGTH_SHORT).show()
                }
            }
        }.addOnFailureListener {
            Toast.makeText(context, "map_location_denied".localized, Toast.LENGTH_SHORT).show()
        }
    } catch (_: SecurityException) {
        Toast.makeText(context, "map_location_denied".localized, Toast.LENGTH_SHORT).show()
    }
}

private fun createPickerMarkerBitmap(context: Context): Bitmap {
    val density = context.resources.displayMetrics.density
    val size = (42 * density).toInt().coerceAtLeast(1)
    val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)

    val shadowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = android.graphics.Color.argb(70, 0, 0, 0)
    }
    canvas.drawCircle(size / 2f, size / 2f, size / 2f, shadowPaint)

    val whitePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = android.graphics.Color.WHITE
    }
    canvas.drawCircle(size / 2f, size / 2f, size / 2f - 2 * density, whitePaint)

    val accentPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = android.graphics.Color.rgb(16, 185, 129) // ZholdasAccent
    }
    canvas.drawCircle(size / 2f, size / 2f, size / 2f - 5 * density, accentPaint)

    canvas.drawCircle(size / 2f, size / 2f, 5 * density, whitePaint)
    return bitmap
}
