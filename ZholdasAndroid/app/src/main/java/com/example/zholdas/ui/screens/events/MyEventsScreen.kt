package com.example.zholdas.ui.screens.events

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.EventBusy
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.example.zholdas.data.model.Event
import com.example.zholdas.theme.ZholdasBackground
import com.example.zholdas.theme.ZholdasTextSecondary

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MyEventsScreen(viewModel: EventsViewModel, onBack: () -> Unit, onEventClick: (Event) -> Unit) {
    val events by viewModel.events.collectAsState()
    val currentUserID by viewModel.currentUserID.collectAsState()
    val errorMessage by viewModel.errorMessage.collectAsState()
    var filter by remember { mutableStateOf(MyEventsFilter.CREATED) }
    val filtered = remember(events, currentUserID, filter) { filterMyEvents(events, currentUserID, filter) }

    LaunchedEffect(Unit) { viewModel.loadCurrentUser() }

    Scaffold(
        containerColor = ZholdasBackground,
        topBar = {
            TopAppBar(
                title = { Text("Мои события", color = Color.White, fontWeight = FontWeight.Bold) },
                navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "Назад", tint = Color.White) } },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = ZholdasBackground)
            )
        }
    ) { padding ->
        Column(Modifier.fillMaxSize().padding(padding).background(ZholdasBackground)) {
            errorMessage?.let { message ->
                Surface(
                    color = MaterialTheme.colorScheme.errorContainer,
                    contentColor = MaterialTheme.colorScheme.onErrorContainer,
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
                    shape = MaterialTheme.shapes.medium
                ) { Text(message, modifier = Modifier.padding(12.dp)) }
            }
            SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth().padding(16.dp)) {
                MyEventsFilter.entries.forEachIndexed { index, item ->
                    SegmentedButton(
                        selected = filter == item,
                        onClick = { filter = item },
                        shape = SegmentedButtonDefaults.itemShape(index, MyEventsFilter.entries.size),
                        label = { Text(when (item) { MyEventsFilter.CREATED -> "Созданные"; MyEventsFilter.PARTICIPATING -> "Участвую"; MyEventsFilter.PAST -> "Прошедшие" }) }
                    )
                }
            }
            if (filtered.isEmpty()) {
                Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
                    Icon(Icons.Default.EventBusy, null, tint = ZholdasTextSecondary, modifier = Modifier.size(52.dp))
                    Spacer(Modifier.height(12.dp))
                    Text("Нет таких событий", color = ZholdasTextSecondary)
                }
            } else {
                LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    items(filtered, key = { it.id }) { event -> EventRowCard(event, false, { onEventClick(event) }) }
                }
            }
        }
    }
}
