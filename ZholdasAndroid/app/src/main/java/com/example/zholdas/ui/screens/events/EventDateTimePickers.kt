package com.example.zholdas.ui.screens.events

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CalendarToday
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.zholdas.data.local.Localization
import com.example.zholdas.data.local.localized
import com.example.zholdas.theme.*
import com.example.zholdas.ui.components.ModernCard
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EventDatePickerDialog(
    initialDate: LocalDate,
    allowPastDates: Boolean = false,
    onDismissRequest: () -> Unit,
    onDateSelected: (LocalDate) -> Unit
) {
    val initialMillis = remember(initialDate) {
        initialDate.atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli()
    }
    val selectableDates = remember(allowPastDates) {
        object : SelectableDates {
            override fun isSelectableDate(utcTimeMillis: Long): Boolean {
                if (allowPastDates) return true
                val todayUtc = LocalDate.now().atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli()
                return utcTimeMillis >= todayUtc
            }
        }
    }
    val datePickerState = rememberDatePickerState(
        initialSelectedDateMillis = initialMillis,
        selectableDates = selectableDates
    )

    DatePickerDialog(
        onDismissRequest = onDismissRequest,
        confirmButton = {
            TextButton(
                onClick = {
                    datePickerState.selectedDateMillis?.let { utcMillis ->
                        val selectedLocalDate = Instant.ofEpochMilli(utcMillis)
                            .atZone(ZoneOffset.UTC)
                            .toLocalDate()
                        onDateSelected(selectedLocalDate)
                    }
                    onDismissRequest()
                }
            ) {
                Text("OK", color = ZholdasAccent, fontWeight = FontWeight.Bold)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismissRequest) {
                Text("create_ev_cancel".localized, color = ZholdasTextSecondary)
            }
        },
        colors = DatePickerDefaults.colors(
            containerColor = ZholdasElevatedSurface
        )
    ) {
        DatePicker(
            state = datePickerState,
            colors = DatePickerDefaults.colors(
                containerColor = ZholdasElevatedSurface,
                titleContentColor = ZholdasTextPrimary,
                headlineContentColor = ZholdasTextPrimary,
                weekdayContentColor = ZholdasTextSecondary,
                subheadContentColor = ZholdasTextSecondary,
                yearContentColor = ZholdasTextPrimary,
                currentYearContentColor = ZholdasAccent,
                selectedYearContentColor = Color.White,
                selectedYearContainerColor = ZholdasAccent,
                dayContentColor = ZholdasTextPrimary,
                selectedDayContentColor = Color.White,
                selectedDayContainerColor = ZholdasAccent,
                todayContentColor = ZholdasAccent,
                todayDateBorderColor = ZholdasAccent
            )
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EventTimePickerDialog(
    title: String,
    initialHour: Int,
    initialMinute: Int,
    onDismissRequest: () -> Unit,
    onTimeSelected: (hour: Int, minute: Int) -> Unit
) {
    val timePickerState = rememberTimePickerState(
        initialHour = initialHour,
        initialMinute = initialMinute,
        is24Hour = true
    )

    AlertDialog(
        onDismissRequest = onDismissRequest,
        confirmButton = {
            TextButton(
                onClick = {
                    onTimeSelected(timePickerState.hour, timePickerState.minute)
                    onDismissRequest()
                }
            ) {
                Text("OK", color = ZholdasAccent, fontWeight = FontWeight.Bold)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismissRequest) {
                Text("create_ev_cancel".localized, color = ZholdasTextSecondary)
            }
        },
        containerColor = ZholdasElevatedSurface,
        title = {
            Text(
                text = title,
                color = ZholdasTextPrimary,
                fontWeight = FontWeight.Bold,
                fontSize = 18.sp
            )
        },
        text = {
            Box(
                modifier = Modifier.fillMaxWidth(),
                contentAlignment = Alignment.Center
            ) {
                TimePicker(
                    state = timePickerState,
                    colors = TimePickerDefaults.colors(
                        clockDialColor = ZholdasSurface,
                        clockDialSelectedContentColor = Color.White,
                        clockDialUnselectedContentColor = ZholdasTextPrimary,
                        selectorColor = ZholdasAccent,
                        containerColor = ZholdasElevatedSurface,
                        periodSelectorBorderColor = ZholdasBorder,
                        periodSelectorSelectedContainerColor = ZholdasAccent,
                        periodSelectorUnselectedContainerColor = ZholdasSurface,
                        periodSelectorSelectedContentColor = Color.White,
                        periodSelectorUnselectedContentColor = ZholdasTextPrimary,
                        timeSelectorSelectedContainerColor = ZholdasAccent.copy(alpha = 0.25f),
                        timeSelectorUnselectedContainerColor = ZholdasSurface,
                        timeSelectorSelectedContentColor = ZholdasAccent,
                        timeSelectorUnselectedContentColor = ZholdasTextPrimary
                    )
                )
            }
        }
    )
}

@Composable
fun EventDateTimeSection(
    startDateTime: ZonedDateTime,
    endDateTime: ZonedDateTime,
    onStartDateTimeChange: (ZonedDateTime) -> Unit,
    onEndDateTimeChange: (ZonedDateTime) -> Unit,
    modifier: Modifier = Modifier,
    allowPastStartDate: Boolean = false
) {
    var showDatePicker by remember { mutableStateOf(false) }
    var showStartTimePicker by remember { mutableStateOf(false) }
    var showEndTimePicker by remember { mutableStateOf(false) }

    val currentLocale = remember(Localization.language) {
        when (Localization.language) {
            "kk" -> Locale("kk")
            "en" -> Locale.ENGLISH
            else -> Locale("ru")
        }
    }
    val dateFormatter = remember(currentLocale) {
        DateTimeFormatter.ofPattern("d MMMM yyyy, EEEE", currentLocale)
    }
    val timeFormatter = remember {
        DateTimeFormatter.ofPattern("HH:mm")
    }

    val now = ZonedDateTime.now()
    val isStartInFuture = allowPastStartDate || startDateTime.isAfter(now.minusMinutes(5))
    val isEndAfterStart = endDateTime.isAfter(startDateTime)

    val isNextDay = endDateTime.toLocalDate().isAfter(startDateTime.toLocalDate())
    val endTimeLabel = if (isNextDay) {
        "${endDateTime.format(timeFormatter)} (+1)"
    } else {
        endDateTime.format(timeFormatter)
    }

    ModernCard(modifier = modifier) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Text(
                text = "create_ev_date".localized.uppercase(),
                color = ZholdasTextTertiary,
                fontSize = 11.sp,
                fontWeight = FontWeight.Bold
            )

            // Date picker trigger button
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(ZholdasSurface)
                    .border(1.dp, ZholdasBorder, RoundedCornerShape(12.dp))
                    .clickable { showDatePicker = true }
                    .padding(14.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.CalendarToday,
                        contentDescription = null,
                        tint = ZholdasAccent,
                        modifier = Modifier.size(20.dp)
                    )
                    Column {
                        Text(
                            text = "create_ev_date".localized,
                            color = ZholdasTextSecondary,
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold
                        )
                        Text(
                            text = startDateTime.format(dateFormatter),
                            color = ZholdasTextPrimary,
                            fontSize = 14.sp,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                }
                Icon(
                    imageVector = Icons.Default.ChevronRight,
                    contentDescription = null,
                    tint = ZholdasTextSecondary
                )
            }

            // Time pickers: Start & End
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                // Start Time Button
                Row(
                    modifier = Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(12.dp))
                        .background(ZholdasSurface)
                        .border(1.dp, ZholdasBorder, RoundedCornerShape(12.dp))
                        .clickable { showStartTimePicker = true }
                        .padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.Schedule,
                        contentDescription = null,
                        tint = ZholdasAccent,
                        modifier = Modifier.size(18.dp)
                    )
                    Column {
                        Text(
                            text = "create_ev_start".localized,
                            color = ZholdasTextSecondary,
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold
                        )
                        Text(
                            text = startDateTime.format(timeFormatter),
                            color = ZholdasTextPrimary,
                            fontSize = 15.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }
                }

                // End Time Button
                Row(
                    modifier = Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(12.dp))
                        .background(ZholdasSurface)
                        .border(1.dp, ZholdasBorder, RoundedCornerShape(12.dp))
                        .clickable { showEndTimePicker = true }
                        .padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.Schedule,
                        contentDescription = null,
                        tint = ZholdasAccent,
                        modifier = Modifier.size(18.dp)
                    )
                    Column {
                        Text(
                            text = "create_ev_end".localized,
                            color = ZholdasTextSecondary,
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold
                        )
                        Text(
                            text = endTimeLabel,
                            color = ZholdasTextPrimary,
                            fontSize = 15.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }
                }
            }

            // Validation error messages
            if (!isStartInFuture) {
                Text(
                    text = "ev_err_start_future".localized,
                    color = ZholdasDanger,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Medium
                )
            }
            if (!isEndAfterStart) {
                Text(
                    text = "ev_err_end_after_start".localized,
                    color = ZholdasDanger,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Medium
                )
            }
        }
    }

    if (showDatePicker) {
        EventDatePickerDialog(
            initialDate = startDateTime.toLocalDate(),
            allowPastDates = allowPastStartDate,
            onDismissRequest = { showDatePicker = false },
            onDateSelected = { selectedDate ->
                val newStart = startDateTime.withYear(selectedDate.year)
                    .withMonth(selectedDate.monthValue)
                    .withDayOfMonth(selectedDate.dayOfMonth)

                val dayDiff = java.time.temporal.ChronoUnit.DAYS.between(
                    startDateTime.toLocalDate(),
                    endDateTime.toLocalDate()
                ).coerceAtLeast(0)

                val newEnd = selectedDate.plusDays(dayDiff)
                    .atTime(endDateTime.toLocalTime())
                    .atZone(startDateTime.zone)

                onStartDateTimeChange(newStart)
                if (newEnd.isAfter(newStart)) {
                    onEndDateTimeChange(newEnd)
                } else {
                    onEndDateTimeChange(newStart.plusHours(1))
                }
            }
        )
    }

    if (showStartTimePicker) {
        EventTimePickerDialog(
            title = "create_ev_start".localized,
            initialHour = startDateTime.hour,
            initialMinute = startDateTime.minute,
            onDismissRequest = { showStartTimePicker = false },
            onTimeSelected = { hour, minute ->
                val newStart = startDateTime.withHour(hour).withMinute(minute).withSecond(0).withNano(0)
                onStartDateTimeChange(newStart)
                if (!endDateTime.isAfter(newStart)) {
                    onEndDateTimeChange(newStart.plusHours(1))
                }
            }
        )
    }

    if (showEndTimePicker) {
        EventTimePickerDialog(
            title = "create_ev_end".localized,
            initialHour = endDateTime.hour,
            initialMinute = endDateTime.minute,
            onDismissRequest = { showEndTimePicker = false },
            onTimeSelected = { hour, minute ->
                val sameDay = startDateTime.toLocalDate()
                val candidateSameDay = sameDay.atTime(hour, minute).atZone(startDateTime.zone)
                val newEnd = if (candidateSameDay.isAfter(startDateTime)) {
                    candidateSameDay
                } else {
                    // Next day for overnight events
                    sameDay.plusDays(1).atTime(hour, minute).atZone(startDateTime.zone)
                }
                onEndDateTimeChange(newEnd)
            }
        )
    }
}
