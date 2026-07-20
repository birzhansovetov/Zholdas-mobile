package com.example.zholdas.ui.screens.profile

import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.example.zholdas.data.local.localized
import com.example.zholdas.data.model.ReportRequest
import com.example.zholdas.theme.*
import com.example.zholdas.ui.AuthViewModel
import com.example.zholdas.ui.components.ModernCard
import com.example.zholdas.ui.components.PrimaryButton
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ReportScreen(
    reportedUserID: String? = null,
    eventID: Int? = null,
    messageID: Int? = null,
    authViewModel: AuthViewModel,
    onBack: () -> Unit,
    modifier: Modifier = Modifier
) {
    val coroutineScope = rememberCoroutineScope()
    val context = LocalContext.current

    val reasons = remember {
        listOf(
            "rep_reason_spam".localized,
            "rep_reason_harassment".localized,
            "rep_reason_violence".localized,
            "rep_reason_inappropriate".localized,
            "rep_reason_other".localized
        )
    }

    var selectedReason by remember { mutableStateOf<String?>(null) }
    var descriptionText by remember { mutableStateOf("") }
    var isSubmitting by remember { mutableStateOf(false) }
    var showAlert by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "rep_title".localized,
                        style = MaterialTheme.typography.titleMedium.copy(
                            fontWeight = FontWeight.Bold,
                            color = ZholdasTextPrimary
                        )
                    )
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
        },
        containerColor = ZholdasBackground
    ) { innerPadding ->
        Column(
            modifier = modifier
                .fillMaxSize()
                .padding(innerPadding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Text(
                text = "rep_info_text".localized,
                style = MaterialTheme.typography.bodyMedium.copy(color = ZholdasTextSecondary)
            )

            ModernCard {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    reasons.forEach { reason ->
                        val isSelected = selectedReason == reason
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(12.dp))
                                .background(if (isSelected) ZholdasElevatedSurface else Color.Transparent)
                                .clickable { selectedReason = reason }
                                .padding(horizontal = 12.dp, vertical = 14.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = reason,
                                style = MaterialTheme.typography.bodyMedium.copy(
                                    color = if (isSelected) ZholdasAccent else ZholdasTextPrimary,
                                    fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal
                                )
                            )
                            if (isSelected) {
                                Icon(
                                    imageVector = Icons.Default.Check,
                                    contentDescription = null,
                                    tint = ZholdasAccent
                                )
                            }
                        }
                    }
                }
            }

            Text(
                text = "rep_details_title".localized,
                style = MaterialTheme.typography.labelMedium.copy(
                    fontWeight = FontWeight.Bold,
                    color = ZholdasTextSecondary
                )
            )

            OutlinedTextField(
                value = descriptionText,
                onValueChange = { descriptionText = it },
                placeholder = {
                    Text("rep_details_placeholder".localized, color = ZholdasTextSecondary)
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(130.dp),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedTextColor = ZholdasTextPrimary,
                    unfocusedTextColor = ZholdasTextPrimary,
                    focusedBorderColor = ZholdasAccent,
                    unfocusedBorderColor = ZholdasBorder
                )
            )

            Spacer(modifier = Modifier.height(8.dp))

            PrimaryButton(
                text = "rep_submit_btn".localized,
                onClick = {
                    val reason = selectedReason ?: return@PrimaryButton
                    coroutineScope.launch {
                        isSubmitting = true
                        try {
                            authViewModel.apiClient.apiService.createReport(
                                ReportRequest(
                                    reportedUserID = reportedUserID,
                                    eventID = eventID,
                                    messageID = messageID,
                                    reason = reason,
                                    description = descriptionText
                                )
                            )
                            showAlert = true
                        } catch (e: Exception) {
                            Toast.makeText(context, e.message ?: "Error submitting report", Toast.LENGTH_SHORT).show()
                        } finally {
                            isSubmitting = false
                        }
                    }
                },
                isLoading = isSubmitting,
                enabled = selectedReason != null
            )
        }

        if (showAlert) {
            AlertDialog(
                onDismissRequest = {
                    showAlert = false
                    onBack()
                },
                containerColor = ZholdasElevatedSurface,
                title = {
                    Text(
                        text = "rep_alert_title".localized,
                        style = MaterialTheme.typography.titleMedium.copy(
                            fontWeight = FontWeight.Bold,
                            color = ZholdasTextPrimary
                        )
                    )
                },
                text = {
                    Text(
                        text = "rep_alert_message".localized,
                        style = MaterialTheme.typography.bodyMedium.copy(color = ZholdasTextSecondary)
                    )
                },
                confirmButton = {
                    Button(
                        onClick = {
                            showAlert = false
                            onBack()
                        },
                        colors = ButtonDefaults.buttonColors(containerColor = ZholdasAccent)
                    ) {
                        Text(
                            text = "btn_ok".localized,
                            color = Color.Black,
                            fontWeight = FontWeight.Bold
                        )
                    }
                }
            )
        }
    }
}
