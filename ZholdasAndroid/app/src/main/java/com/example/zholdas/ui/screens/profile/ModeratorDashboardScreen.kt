package com.example.zholdas.ui.screens.profile

import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.material3.TabRowDefaults.tabIndicatorOffset
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.zholdas.data.local.localized
import com.example.zholdas.data.model.*
import com.example.zholdas.theme.*
import com.example.zholdas.ui.AuthViewModel
import com.example.zholdas.ui.ModeratorDashboardUseCases
import com.example.zholdas.ui.components.ModernCard
import com.example.zholdas.ui.components.PrimaryButton
import com.example.zholdas.ui.components.modernFieldSurface
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ModeratorDashboardScreen(
    authViewModel: AuthViewModel,
    onBack: () -> Unit,
    modifier: Modifier = Modifier
) {
    val coroutineScope = rememberCoroutineScope()
    val context = LocalContext.current
    val currentUserProfile by authViewModel.currentUserProfile.collectAsState()
    val isAdmin = currentUserProfile?.role?.equals("admin", ignoreCase = true) == true

    var selectedTabIndex by remember { mutableStateOf(0) }
    var isLoading by remember { mutableStateOf(false) }

    // Data states
    var reports by remember { mutableStateOf<List<Report>>(emptyList()) }
    var stats by remember { mutableStateOf<ModerationStats?>(null) }
    var users by remember { mutableStateOf<List<ModerationUser>>(emptyList()) }
    var events by remember { mutableStateOf<List<Event>>(emptyList()) }

    // Ban modal sheet state
    var showBanSheet by remember { mutableStateOf(false) }
    var banTargetUserId by remember { mutableStateOf("") }
    var banTargetReportId by remember { mutableStateOf<Int?>(null) }
    var banReasonInput by remember { mutableStateOf("") }

    // Search & Filter states
    var userSearchText by remember { mutableStateOf("") }
    var eventSearchText by remember { mutableStateOf("") }
    var eventStatusFilter by remember { mutableStateOf("All") } // All, Active, Closed, Cancelled

    // Tools state
    var broadcastTitle by remember { mutableStateOf("") }
    var broadcastText by remember { mutableStateOf("") }
    var aiEnabled by remember { mutableStateOf(true) }
    var defaultCity by remember { mutableStateOf("Almaty") }
    var aiRateLimit by remember { mutableStateOf("20") }
    var isSendingBroadcast by remember { mutableStateOf(false) }
    var isSavingSettings by remember { mutableStateOf(false) }
    var toolsError by remember { mutableStateOf<String?>(null) }
    var auditLogs by remember { mutableStateOf<List<ModerationAuditLog>>(emptyList()) }
    var auditError by remember { mutableStateOf<String?>(null) }
    val moderationUseCases = remember(authViewModel.apiClient.apiService) { ModeratorDashboardUseCases(authViewModel.apiClient.apiService) }

    fun refreshAllData() {
        coroutineScope.launch {
            isLoading = true
            try {
                reports = authViewModel.apiClient.apiService.getReports()
            } catch (e: Exception) {
                reports = emptyList()
            }
            try {
                stats = authViewModel.apiClient.apiService.getModerationStats()
            } catch (e: Exception) {
                stats = ModerationStats()
            }
            try {
                users = authViewModel.apiClient.apiService.getModerationUsers()
            } catch (e: Exception) {
                users = emptyList()
            }
            try {
                events = authViewModel.apiClient.apiService.getModerationEvents()
            } catch (e: Exception) {
                events = emptyList()
            }
            if (isAdmin) {
                try {
                    val settings = authViewModel.apiClient.apiService.getModerationSettings()
                    aiEnabled = settings.aiEnabled
                    aiRateLimit = settings.aiRateLimitPer10m.toString()
                    defaultCity = settings.defaultCity
                    toolsError = null
                } catch (e: Exception) {
                    toolsError = e.message ?: "mod_settings_load_error".localized
                }
                try {
                    auditLogs = authViewModel.apiClient.apiService.getModerationAuditLogs()
                    auditError = null
                } catch (e: Exception) {
                    auditError = e.message ?: "mod_audit_load_error".localized
                }
            }
            isLoading = false
        }
    }

    LaunchedEffect(Unit) {
        refreshAllData()
    }

    Scaffold(
        topBar = {
            Column(modifier = Modifier.background(ZholdasBackground)) {
                TopAppBar(
                    title = {
                        Column {
                            Text(
                                text = "mod_nav_title".localized,
                                style = MaterialTheme.typography.titleMedium.copy(
                                    fontWeight = FontWeight.Bold,
                                    color = ZholdasTextPrimary
                                )
                            )
                            Text(
                                text = if (isAdmin) "mod_announcement".localized else "mod_moderation".localized,
                                style = MaterialTheme.typography.bodySmall.copy(
                                    color = MaterialTheme.colorScheme.primary
                                )
                            )
                        }
                    },
                    navigationIcon = {
                        IconButton(onClick = onBack) {
                            Icon(
                                imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                                contentDescription = "Back",
                                tint = ZholdasTextPrimary
                            )
                        }
                    },
                    colors = TopAppBarDefaults.topAppBarColors(
                        containerColor = ZholdasBackground
                    )
                )

                // Subtitle description
                Text(
                    text = "mod_subtitle".localized,
                    style = MaterialTheme.typography.bodySmall.copy(
                        color = ZholdasTextSecondary
                    ),
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp)
                )

                // 5 Tabs selector
                val tabTitles = buildList {
                    addAll(listOf(
                    "mod_tab_moderation".localized,
                    "mod_tab_stats".localized,
                    "mod_tab_users".localized,
                    "mod_tab_events".localized
                    ))
                    if (isAdmin) { add("mod_tab_tools".localized); add("mod_audit_tab".localized) }
                }
                ScrollableTabRow(
                    selectedTabIndex = selectedTabIndex,
                    containerColor = ZholdasBackground,
                    contentColor = MaterialTheme.colorScheme.primary,
                    edgePadding = 16.dp,
                    indicator = { tabPositions ->
                        if (selectedTabIndex < tabPositions.size) {
                            TabRowDefaults.SecondaryIndicator(
                                Modifier.tabIndicatorOffset(tabPositions[selectedTabIndex]),
                                color = MaterialTheme.colorScheme.primary
                            )
                        }
                    }
                ) {
                    tabTitles.forEachIndexed { idx, title ->
                        Tab(
                            selected = selectedTabIndex == idx,
                            onClick = { selectedTabIndex = idx },
                            text = {
                                Text(
                                    text = title,
                                    style = MaterialTheme.typography.labelMedium.copy(
                                        fontWeight = if (selectedTabIndex == idx) FontWeight.Bold else FontWeight.Normal,
                                        color = if (selectedTabIndex == idx) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                )
                            }
                        )
                    }
                }
            }
        },
        containerColor = ZholdasBackground
    ) { innerPadding ->
        Box(
            modifier = modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            when (selectedTabIndex) {
                0 -> ModerationReportsTab(
                    reports = reports,
                    onDismiss = { reportId ->
                        coroutineScope.launch {
                            try {
                                authViewModel.apiClient.apiService.closeReport(reportId)
                                refreshAllData()
                            } catch (e: Exception) {
                                Toast.makeText(context, e.message ?: "Error", Toast.LENGTH_SHORT).show()
                            }
                        }
                    },
                    onOpenBanSheet = { userId, reportId ->
                        banTargetUserId = userId
                        banTargetReportId = reportId
                        banReasonInput = ""
                        showBanSheet = true
                    }
                )
                1 -> ModerationStatsTab(stats = stats ?: ModerationStats())
                2 -> ModerationUsersTab(
                    users = users,
                    searchText = userSearchText,
                    onSearchTextChange = { userSearchText = it },
                    onBanUser = { userId ->
                        banTargetUserId = userId
                        banTargetReportId = null
                        banReasonInput = ""
                        showBanSheet = true
                    },
                    onUnbanUser = { userId ->
                        coroutineScope.launch {
                            try {
                                authViewModel.apiClient.apiService.unbanUser(userId)
                                refreshAllData()
                            } catch (e: Exception) {
                                Toast.makeText(context, e.message ?: "Error", Toast.LENGTH_SHORT).show()
                            }
                        }
                    },
                    onRoleChange = { userId, newRole ->
                        coroutineScope.launch {
                            try {
                                authViewModel.apiClient.apiService.updateUserRole(userId, RoleRequest(newRole))
                                refreshAllData()
                            } catch (e: Exception) {
                                Toast.makeText(context, e.message ?: "Error", Toast.LENGTH_SHORT).show()
                            }
                        }
                    },
                    onDeletePermanently = { userId ->
                        coroutineScope.launch {
                            try {
                                authViewModel.apiClient.apiService.deleteUserPermanently(userId)
                                refreshAllData()
                            } catch (e: Exception) {
                                Toast.makeText(context, e.message ?: "Error", Toast.LENGTH_SHORT).show()
                            }
                        }
                    }
                )
                3 -> ModerationEventsTab(
                    events = events,
                    searchText = eventSearchText,
                    onSearchTextChange = { eventSearchText = it },
                    statusFilter = eventStatusFilter,
                    onStatusFilterChange = { eventStatusFilter = it },
                    onUpdateStatus = { eventId, newStatus ->
                        coroutineScope.launch {
                            try {
                                authViewModel.apiClient.apiService.updateEventStatus(eventId, StatusRequest(newStatus))
                                refreshAllData()
                            } catch (e: Exception) {
                                Toast.makeText(context, e.message ?: "Error", Toast.LENGTH_SHORT).show()
                            }
                        }
                    }
                )
                4 -> ModerationToolsTab(
                    broadcastTitle = broadcastTitle,
                    onBroadcastTitleChange = { broadcastTitle = it },
                    broadcastText = broadcastText,
                    onBroadcastTextChange = { broadcastText = it },
                    isSendingBroadcast = isSendingBroadcast,
                    onSendBroadcast = {
                        if (broadcastTitle.isNotBlank() && broadcastText.isNotBlank()) {
                            coroutineScope.launch {
                                isSendingBroadcast = true
                                try {
                                    authViewModel.apiClient.apiService.broadcastNotification(
                                        BroadcastRequest(broadcastTitle, broadcastText)
                                    )
                                    broadcastTitle = ""
                                    broadcastText = ""
                                    Toast.makeText(context, "mod_tools_settings_saved_msg".localized, Toast.LENGTH_SHORT).show()
                                } catch (e: Exception) {
                                    Toast.makeText(context, e.message ?: "Error", Toast.LENGTH_SHORT).show()
                                } finally {
                                    isSendingBroadcast = false
                                }
                            }
                        }
                    },
                    aiEnabled = aiEnabled,
                    onAiEnabledChange = { aiEnabled = it },
                    defaultCity = defaultCity,
                    onDefaultCityChange = { defaultCity = it },
                    aiRateLimit = aiRateLimit,
                    onAiRateLimitChange = { aiRateLimit = it.filter(Char::isDigit); toolsError = null },
                    isSavingSettings = isSavingSettings,
                    settingsError = toolsError,
                    onSaveSettings = {
                        val actor = currentUserProfile
                        val validation = moderationUseCases.validateSettings(aiRateLimit, defaultCity)
                        if (actor == null) toolsError = "mod_settings_admin_profile_error".localized
                        else if (!validation.isValid) toolsError = if ((aiRateLimit.toIntOrNull() ?: 0) !in 1..100) {
                            "mod_settings_rate_error".localized
                        } else {
                            "mod_settings_city_error".localized
                        }
                        else coroutineScope.launch {
                            isSavingSettings = true
                            toolsError = null
                            try {
                                val saved = moderationUseCases.saveSettings(actor, aiEnabled, aiRateLimit, defaultCity)
                                aiEnabled = saved.aiEnabled
                                aiRateLimit = saved.aiRateLimitPer10m.toString()
                                defaultCity = saved.defaultCity
                                Toast.makeText(context, "mod_tools_settings_saved_msg".localized, Toast.LENGTH_SHORT).show()
                                auditLogs = authViewModel.apiClient.apiService.getModerationAuditLogs()
                            } catch (e: Exception) {
                                toolsError = e.message ?: "mod_settings_save_error".localized
                            } finally { isSavingSettings = false }
                        }
                    }
                )
                5 -> ModerationAuditTab(auditLogs, isLoading, auditError) { refreshAllData() }
            }

            if (showBanSheet) {
                AlertDialog(
                    onDismissRequest = { showBanSheet = false },
                    containerColor = ZholdasElevatedSurface,
                    title = {
                        Text(
                            text = "mod_ban_sheet_title".localized,
                            style = MaterialTheme.typography.titleLarge.copy(
                                fontWeight = FontWeight.Bold,
                                color = ZholdasTextPrimary
                            )
                        )
                    },
                    text = {
                        Column {
                            OutlinedTextField(
                                value = banReasonInput,
                                onValueChange = { banReasonInput = it },
                                label = {
                                    Text(
                                        text = "mod_ban_sheet_reason_placeholder".localized,
                                        color = ZholdasTextSecondary
                                    )
                                },
                                modifier = Modifier.fillMaxWidth(),
                                colors = OutlinedTextFieldDefaults.colors(
                                    focusedTextColor = ZholdasTextPrimary,
                                    unfocusedTextColor = ZholdasTextPrimary,
                                    focusedBorderColor = MaterialTheme.colorScheme.primary,
                                    unfocusedBorderColor = ZholdasBorder
                                )
                            )
                        }
                    },
                    confirmButton = {
                        Button(
                            onClick = {
                                showBanSheet = false
                                coroutineScope.launch {
                                    try {
                                        if (banTargetUserId.isNotEmpty()) {
                                            authViewModel.apiClient.apiService.banUser(
                                                id = banTargetUserId,
                                                request = BanRequest(banReasonInput),
                                                reason = banReasonInput
                                            )
                                        }
                                        banTargetReportId?.let { reportId ->
                                            authViewModel.apiClient.apiService.closeReport(reportId)
                                        }
                                        refreshAllData()
                                    } catch (e: Exception) {
                                        Toast.makeText(context, e.message ?: "Error", Toast.LENGTH_SHORT).show()
                                    }
                                }
                            },
                            colors = ButtonDefaults.buttonColors(
                                containerColor = Color(0xFFE53935)
                            )
                        ) {
                            Text(
                                text = "mod_btn_ban".localized,
                                color = Color.White,
                                fontWeight = FontWeight.Bold
                            )
                        }
                    },
                    dismissButton = {
                        TextButton(onClick = { showBanSheet = false }) {
                            Text(
                                text = "btn_cancel".localized,
                                color = ZholdasTextSecondary
                            )
                        }
                    }
                )
            }
        }
    }
}

// MARK: - Tab 0: Moderation Reports
@Composable
private fun ModerationReportsTab(
    reports: List<Report>,
    onDismiss: (Int) -> Unit,
    onOpenBanSheet: (String, Int) -> Unit
) {
    if (reports.isEmpty()) {
        Box(
            modifier = Modifier.fillMaxSize(),
            contentAlignment = Alignment.Center
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(
                    imageVector = Icons.Default.CheckCircle,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(64.dp)
                )
                Spacer(modifier = Modifier.height(16.dp))
                Text(
                    text = "mod_reports_empty_title".localized,
                    style = MaterialTheme.typography.titleMedium.copy(
                        color = ZholdasTextPrimary,
                        fontWeight = FontWeight.Bold
                    )
                )
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = "mod_reports_empty_desc".localized,
                    style = MaterialTheme.typography.bodyMedium.copy(
                        color = ZholdasTextSecondary
                    ),
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(horizontal = 32.dp)
                )
            }
        }
    } else {
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            items(reports) { report ->
                ModernCard {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = "${"mod_reporter_label".localized} ${report.reporterName}",
                                style = MaterialTheme.typography.labelMedium.copy(
                                    color = ZholdasTextSecondary
                                )
                            )
                            Box(
                                modifier = Modifier
                                    .clip(RoundedCornerShape(8.dp))
                                    .background(Color(0xFFE53935).copy(alpha = 0.15f))
                                    .padding(horizontal = 8.dp, vertical = 4.dp)
                            ) {
                                Text(
                                    text = report.reason.uppercase(),
                                    style = MaterialTheme.typography.labelSmall.copy(
                                        color = Color(0xFFE53935),
                                        fontWeight = FontWeight.Bold
                                    )
                                )
                            }
                        }

                        report.reportedUserName?.let { reportedName ->
                            Text(
                                text = "${"mod_reported_label".localized} $reportedName",
                                style = MaterialTheme.typography.bodyMedium.copy(
                                    color = ZholdasTextPrimary,
                                    fontWeight = FontWeight.Bold
                                )
                            )
                        }

                        report.eventTitle?.let { title ->
                            Text(
                                text = "${"mod_event_label".localized} $title",
                                style = MaterialTheme.typography.bodySmall.copy(
                                    color = MaterialTheme.colorScheme.primary
                                )
                            )
                        }

                        if (report.description.isNotBlank()) {
                            Text(
                                text = report.description,
                                style = MaterialTheme.typography.bodySmall.copy(
                                    color = ZholdasTextPrimary
                                )
                            )
                        }

                        Spacer(modifier = Modifier.height(4.dp))
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.End
                        ) {
                            OutlinedButton(
                                onClick = { onDismiss(report.id) },
                                colors = ButtonDefaults.outlinedButtonColors(
                                    contentColor = ZholdasTextSecondary
                                )
                            ) {
                                Text("mod_btn_dismiss".localized)
                            }

                            Spacer(modifier = Modifier.width(8.dp))

                            Button(
                                onClick = {
                                    report.reportedUserID?.let { reportedId ->
                                        onOpenBanSheet(reportedId, report.id)
                                    }
                                },
                                colors = ButtonDefaults.buttonColors(
                                    containerColor = Color(0xFFE53935)
                                ),
                                enabled = report.reportedUserID != null
                            ) {
                                Text("mod_btn_ban".localized, color = Color.White)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Tab 1: Moderation Stats
@Composable
private fun ModerationStatsTab(stats: ModerationStats) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text(
            text = "mod_stats_title".localized,
            style = MaterialTheme.typography.titleMedium.copy(
                fontWeight = FontWeight.Bold,
                color = ZholdasTextPrimary
            )
        )

        val totalUsersVal = if (stats.users > 0) stats.users else stats.totalUsers
        val totalEventsVal = if (stats.events > 0) stats.events else stats.totalEvents
        val totalMessagesVal = if (stats.messages > 0) stats.messages else stats.totalMessages

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            StatBox(
                modifier = Modifier.weight(1f),
                title = "mod_stats_users".localized,
                value = "$totalUsersVal",
                color = MaterialTheme.colorScheme.primary
            )
            StatBox(
                modifier = Modifier.weight(1f),
                title = "mod_stats_events".localized,
                value = "$totalEventsVal",
                color = Color(0xFF4CAF50)
            )
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            StatBox(
                modifier = Modifier.weight(1f),
                title = "mod_stats_active".localized,
                value = "${stats.activeEvents}",
                color = Color(0xFFFFA000)
            )
            StatBox(
                modifier = Modifier.weight(1f),
                title = "mod_stats_messages".localized,
                value = "$totalMessagesVal",
                color = Color(0xFF42A5F5)
            )
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            StatBox(
                modifier = Modifier.weight(1f),
                title = "mod_stats_reports".localized,
                value = "${stats.reports}",
                color = Color(0xFFAB47BC)
            )
            StatBox(
                modifier = Modifier.weight(1f),
                title = "mod_stats_bans".localized,
                value = "${stats.bans}",
                color = Color(0xFFE53935)
            )
        }

        Spacer(modifier = Modifier.height(8.dp))

        Text(
            text = "mod_analytics_title".localized,
            style = MaterialTheme.typography.titleMedium.copy(
                fontWeight = FontWeight.Bold,
                color = ZholdasTextPrimary
            )
        )

        ModernCard {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                AnalyticsRow("mod_anal_reg_today".localized, stats.regToday)
                AnalyticsRow("mod_anal_reg_7d".localized, stats.reg7Days)
                AnalyticsRow("mod_anal_reg_30d".localized, stats.reg30Days)
                HorizontalDivider(color = ZholdasBorder)
                AnalyticsRow("mod_anal_ev_7d".localized, stats.events7Days)
                AnalyticsRow("mod_anal_ev_30d".localized, stats.events30Days)
                HorizontalDivider(color = ZholdasBorder)
                AnalyticsRow("mod_anal_joins_7d".localized, stats.joins7Days)
            }
        }
    }
}

@Composable
private fun StatBox(
    title: String,
    value: String,
    color: Color,
    modifier: Modifier = Modifier
) {
    ModernCard(modifier = modifier) {
        Column {
            Text(
                text = title,
                style = MaterialTheme.typography.labelSmall.copy(color = ZholdasTextSecondary)
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = value,
                style = MaterialTheme.typography.headlineSmall.copy(
                    fontWeight = FontWeight.Bold,
                    color = color
                )
            )
        }
    }
}

@Composable
private fun AnalyticsRow(label: String, valNum: Int) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodyMedium.copy(color = ZholdasTextSecondary)
        )
        Text(
            text = "$valNum",
            style = MaterialTheme.typography.bodyMedium.copy(
                color = ZholdasTextPrimary,
                fontWeight = FontWeight.Bold
            )
        )
    }
}

// MARK: - Tab 2: Moderation Users
@Composable
private fun ModerationUsersTab(
    users: List<ModerationUser>,
    searchText: String,
    onSearchTextChange: (String) -> Unit,
    onBanUser: (String) -> Unit,
    onUnbanUser: (String) -> Unit,
    onRoleChange: (String, String) -> Unit,
    onDeletePermanently: (String) -> Unit
) {
    val filteredUsers = remember(users, searchText) {
        if (searchText.isBlank()) users
        else users.filter { u ->
            u.fullName.contains(searchText, ignoreCase = true) ||
                    u.username.contains(searchText, ignoreCase = true) ||
                    u.email.contains(searchText, ignoreCase = true) ||
                    u.id.contains(searchText, ignoreCase = true)
        }
    }

    Column(modifier = Modifier.fillMaxSize()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = "mod_users_title".localized,
                style = MaterialTheme.typography.titleMedium.copy(
                    fontWeight = FontWeight.Bold,
                    color = ZholdasTextPrimary
                )
            )
            Spacer(modifier = Modifier.height(8.dp))
            OutlinedTextField(
                value = searchText,
                onValueChange = onSearchTextChange,
                placeholder = {
                    Text(
                        text = "mod_users_search_placeholder".localized,
                        color = ZholdasTextSecondary
                    )
                },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                colors = OutlinedTextFieldDefaults.colors(
                    focusedTextColor = ZholdasTextPrimary,
                    unfocusedTextColor = ZholdasTextPrimary,
                    focusedBorderColor = MaterialTheme.colorScheme.primary,
                    unfocusedBorderColor = ZholdasBorder
                )
            )
        }

        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            items(filteredUsers) { u ->
                ModernCard {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.SpaceBetween,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = u.fullName.ifBlank { u.username.ifBlank { u.email } },
                                    style = MaterialTheme.typography.bodyMedium.copy(
                                        color = ZholdasTextPrimary,
                                        fontWeight = FontWeight.Bold
                                    ),
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis
                                )
                                Text(
                                    text = "ID: ${u.id.take(8)}... | Role: ${u.role}",
                                    style = MaterialTheme.typography.bodySmall.copy(
                                        color = ZholdasTextSecondary
                                    )
                                )
                            }

                            if (u.isBanned) {
                                Box(
                                    modifier = Modifier
                                        .clip(RoundedCornerShape(6.dp))
                                        .background(Color(0xFFE53935).copy(alpha = 0.2f))
                                        .padding(horizontal = 8.dp, vertical = 4.dp)
                                ) {
                                    Text(
                                        text = "mod_user_banned_label".localized,
                                        style = MaterialTheme.typography.labelSmall.copy(
                                            color = Color(0xFFE53935),
                                            fontWeight = FontWeight.Bold
                                        )
                                    )
                                }
                            }
                        }

                        // Roles selector
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            Text(
                                text = "mod_user_roles_label".localized,
                                style = MaterialTheme.typography.labelSmall.copy(color = ZholdasTextSecondary)
                            )

                            listOf("user", "moderator", "admin").forEach { role ->
                                val isCurrent = u.role == role
                                Box(
                                    modifier = Modifier
                                        .clip(RoundedCornerShape(8.dp))
                                        .background(if (isCurrent) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceContainerHigh)
                                        .clickable { if (!isCurrent) onRoleChange(u.id, role) }
                                        .padding(horizontal = 10.dp, vertical = 6.dp)
                                ) {
                                    Text(
                                        text = role,
                                        style = MaterialTheme.typography.labelSmall.copy(
                                            color = if (isCurrent) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurface,
                                            fontWeight = if (isCurrent) FontWeight.Bold else FontWeight.Normal
                                        )
                                    )
                                }
                            }
                        }

                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.End,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            if (u.isBanned) {
                                Button(
                                    onClick = { onUnbanUser(u.id) },
                                    colors = ButtonDefaults.buttonColors(
                                        containerColor = Color(0xFF4CAF50)
                                    )
                                ) {
                                    Text("mod_btn_unban".localized, color = Color.White)
                                }
                            } else {
                                Button(
                                    onClick = { onBanUser(u.id) },
                                    colors = ButtonDefaults.buttonColors(
                                        containerColor = Color(0xFFFFA000)
                                    )
                                ) {
                                    Text("mod_btn_ban".localized, color = Color.White)
                                }
                            }

                            Spacer(modifier = Modifier.width(8.dp))

                            IconButton(
                                onClick = { onDeletePermanently(u.id) }
                            ) {
                                Icon(
                                    imageVector = Icons.Default.Delete,
                                    contentDescription = "mod_btn_delete_perm".localized,
                                    tint = Color(0xFFE53935)
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Tab 3: Moderation Events
@Composable
private fun ModerationEventsTab(
    events: List<Event>,
    searchText: String,
    onSearchTextChange: (String) -> Unit,
    statusFilter: String,
    onStatusFilterChange: (String) -> Unit,
    onUpdateStatus: (Int, String) -> Unit
) {
    val filteredEvents = remember(events, searchText, statusFilter) {
        events.filter { ev ->
            val matchesSearch = searchText.isBlank() || ev.title.contains(searchText, ignoreCase = true)
            val matchesStatus = when (statusFilter) {
                "Active" -> ev.status == "active"
                "Closed" -> ev.status == "finished"
                "Cancelled" -> ev.status == "cancelled"
                else -> true
            }
            matchesSearch && matchesStatus
        }
    }

    Column(modifier = Modifier.fillMaxSize()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = "mod_events_title".localized,
                style = MaterialTheme.typography.titleMedium.copy(
                    fontWeight = FontWeight.Bold,
                    color = ZholdasTextPrimary
                )
            )
            Spacer(modifier = Modifier.height(8.dp))
            OutlinedTextField(
                value = searchText,
                onValueChange = onSearchTextChange,
                placeholder = {
                    Text(
                        text = "mod_events_search_placeholder".localized,
                        color = ZholdasTextSecondary
                    )
                },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                colors = OutlinedTextFieldDefaults.colors(
                    focusedTextColor = ZholdasTextPrimary,
                    unfocusedTextColor = ZholdasTextPrimary,
                    focusedBorderColor = MaterialTheme.colorScheme.primary,
                    unfocusedBorderColor = ZholdasBorder
                )
            )
            Spacer(modifier = Modifier.height(8.dp))

            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf(
                    "All" to "mod_events_filter_all".localized,
                    "Active" to "mod_events_filter_active".localized,
                    "Closed" to "mod_events_filter_closed".localized,
                    "Cancelled" to "mod_events_filter_cancelled".localized
                ).forEach { (key, label) ->
                    val isSel = statusFilter == key
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(12.dp))
                            .background(if (isSel) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceContainerHigh)
                            .clickable { onStatusFilterChange(key) }
                            .padding(horizontal = 12.dp, vertical = 6.dp)
                    ) {
                        Text(
                            text = label,
                            style = MaterialTheme.typography.labelMedium.copy(
                                color = if (isSel) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurface,
                                fontWeight = if (isSel) FontWeight.Bold else FontWeight.Normal
                            )
                        )
                    }
                }
            }
        }

        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            items(filteredEvents) { ev ->
                ModernCard {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = ev.category.uppercase(),
                                style = MaterialTheme.typography.labelSmall.copy(color = MaterialTheme.colorScheme.primary)
                            )

                            val badgeColor = when (ev.status) {
                                "active" -> Color(0xFF4CAF50)
                                "finished" -> Color(0xFF42A5F5)
                                else -> Color(0xFFE53935)
                            }
                            Box(
                                modifier = Modifier
                                    .clip(RoundedCornerShape(6.dp))
                                    .background(badgeColor.copy(alpha = 0.2f))
                                    .padding(horizontal = 8.dp, vertical = 4.dp)
                            ) {
                                Text(
                                    text = ev.status.uppercase(),
                                    style = MaterialTheme.typography.labelSmall.copy(
                                        color = badgeColor,
                                        fontWeight = FontWeight.Bold
                                    )
                                )
                            }
                        }

                        Text(
                            text = ev.title,
                            style = MaterialTheme.typography.titleMedium.copy(
                                color = ZholdasTextPrimary,
                                fontWeight = FontWeight.Bold
                            )
                        )

                        Text(
                            text = "${"mod_creator_label".localized}: ${ev.creatorID.take(8)}...",
                            style = MaterialTheme.typography.bodySmall.copy(color = ZholdasTextSecondary)
                        )

                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.End
                        ) {
                            if (ev.status != "active") {
                                OutlinedButton(
                                    onClick = { onUpdateStatus(ev.id, "active") }
                                ) {
                                    Text("mod_btn_activate".localized)
                                }
                                Spacer(modifier = Modifier.width(8.dp))
                            }
                            if (ev.status != "finished") {
                                OutlinedButton(
                                    onClick = { onUpdateStatus(ev.id, "finished") }
                                ) {
                                    Text("btn_done".localized)
                                }
                                Spacer(modifier = Modifier.width(8.dp))
                            }
                            if (ev.status != "cancelled") {
                                Button(
                                    onClick = { onUpdateStatus(ev.id, "cancelled") },
                                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFE53935))
                                ) {
                                    Text("mod_btn_cancel".localized, color = Color.White)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Tab 4: Moderation Tools
@Composable
private fun ModerationToolsTab(
    broadcastTitle: String,
    onBroadcastTitleChange: (String) -> Unit,
    broadcastText: String,
    onBroadcastTextChange: (String) -> Unit,
    isSendingBroadcast: Boolean,
    onSendBroadcast: () -> Unit,
    aiEnabled: Boolean,
    onAiEnabledChange: (Boolean) -> Unit,
    defaultCity: String,
    onDefaultCityChange: (String) -> Unit,
    aiRateLimit: String,
    onAiRateLimitChange: (String) -> Unit,
    isSavingSettings: Boolean,
    settingsError: String?,
    onSaveSettings: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text(
            text = "mod_tools_broadcast_header".localized,
            style = MaterialTheme.typography.titleMedium.copy(
                fontWeight = FontWeight.Bold,
                color = ZholdasTextPrimary
            )
        )

        ModernCard {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                OutlinedTextField(
                    value = broadcastTitle,
                    onValueChange = onBroadcastTitleChange,
                    label = { Text("mod_tools_broadcast_title_placeholder".localized, color = ZholdasTextSecondary) },
                    modifier = Modifier.fillMaxWidth(),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedTextColor = ZholdasTextPrimary,
                        unfocusedTextColor = ZholdasTextPrimary,
                        focusedBorderColor = MaterialTheme.colorScheme.primary,
                        unfocusedBorderColor = ZholdasBorder
                    )
                )

                OutlinedTextField(
                    value = broadcastText,
                    onValueChange = onBroadcastTextChange,
                    label = { Text("mod_tools_broadcast_text_placeholder".localized, color = ZholdasTextSecondary) },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(100.dp),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedTextColor = ZholdasTextPrimary,
                        unfocusedTextColor = ZholdasTextPrimary,
                        focusedBorderColor = MaterialTheme.colorScheme.primary,
                        unfocusedBorderColor = ZholdasBorder
                    )
                )

                PrimaryButton(
                    text = "mod_tools_broadcast_submit".localized,
                    onClick = onSendBroadcast,
                    isLoading = isSendingBroadcast
                )
            }
        }

        Spacer(modifier = Modifier.height(8.dp))

        Text(
            text = "mod_tools_settings_header".localized,
            style = MaterialTheme.typography.titleMedium.copy(
                fontWeight = FontWeight.Bold,
                color = ZholdasTextPrimary
            )
        )

        ModernCard {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "ai_enabled_label".localized,
                        style = MaterialTheme.typography.bodyMedium.copy(color = ZholdasTextPrimary)
                    )
                    Switch(
                        checked = aiEnabled,
                        onCheckedChange = onAiEnabledChange,
                        colors = SwitchDefaults.colors(
                            checkedThumbColor = MaterialTheme.colorScheme.onPrimary,
                            checkedTrackColor = MaterialTheme.colorScheme.primary
                        )
                    )
                }

                OutlinedTextField(
                    value = defaultCity,
                    onValueChange = onDefaultCityChange,
                    label = { Text("default_city_label".localized, color = ZholdasTextSecondary) },
                    modifier = Modifier.fillMaxWidth(),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedTextColor = ZholdasTextPrimary,
                        unfocusedTextColor = ZholdasTextPrimary,
                        focusedBorderColor = MaterialTheme.colorScheme.primary,
                        unfocusedBorderColor = ZholdasBorder
                    )
                )

                OutlinedTextField(
                    value = aiRateLimit,
                    onValueChange = onAiRateLimitChange,
                    label = { Text("ai_rate_limit_label".localized, color = ZholdasTextSecondary) },
                    modifier = Modifier.fillMaxWidth(),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedTextColor = ZholdasTextPrimary,
                        unfocusedTextColor = ZholdasTextPrimary,
                        focusedBorderColor = MaterialTheme.colorScheme.primary,
                        unfocusedBorderColor = ZholdasBorder
                    )
                )

                PrimaryButton(
                    text = "mod_tools_settings_save".localized,
                    onClick = onSaveSettings,
                    isLoading = isSavingSettings
                )
                settingsError?.let { Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall) }
            }
        }
    }
}

@Composable
private fun ModerationAuditTab(
    logs: List<ModerationAuditLog>,
    isLoading: Boolean,
    error: String?,
    onRetry: () -> Unit
) {
    when {
        isLoading -> Box(Modifier.fillMaxSize().semantics { contentDescription = "mod_audit_loading".localized }, contentAlignment = Alignment.Center) {
            CircularProgressIndicator(color = MaterialTheme.colorScheme.primary)
        }
        error != null -> Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
            Text(error, color = MaterialTheme.colorScheme.error, textAlign = TextAlign.Center, modifier = Modifier.padding(20.dp))
            Button(onClick = onRetry) { Text("mod_audit_retry".localized) }
        }
        logs.isEmpty() -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { Text("mod_audit_empty".localized, color = MaterialTheme.colorScheme.onSurfaceVariant) }
        else -> LazyColumn(
            Modifier.fillMaxSize(),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            items(logs, key = { it.id }) { log ->
                ModernCard {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text(log.actionType.replace('_', ' '), color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold)
                        Text(log.createdAt.take(16).replace('T', ' '), color = ZholdasTextSecondary, fontSize = 11.sp)
                    }
                    Spacer(Modifier.height(6.dp))
                    Text(log.moderatorName.ifBlank { log.moderatorID }, color = ZholdasTextPrimary, fontWeight = FontWeight.SemiBold)
                    Text("${log.targetType}: ${log.targetID}", color = ZholdasTextSecondary, fontSize = 12.sp)
                    if (log.details.isNotBlank()) Text(log.details, color = ZholdasTextSecondary, fontSize = 13.sp, modifier = Modifier.padding(top = 4.dp))
                }
            }
        }
    }
}
