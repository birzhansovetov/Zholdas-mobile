package com.example.zholdas.ui.screens.profile

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ExitToApp
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.platform.LocalContext
import coil.compose.AsyncImage
import com.example.zholdas.ZholdasApplication
import com.example.zholdas.data.local.AppTheme
import com.example.zholdas.data.local.Localization
import com.example.zholdas.data.local.localized
import com.example.zholdas.data.model.User
import com.example.zholdas.theme.*
import com.example.zholdas.ui.AuthViewModel
import com.example.zholdas.ui.components.ModernCard
import java.util.Calendar
import java.util.Locale
import kotlinx.coroutines.launch

@Composable
fun ProfileScreen(
    authViewModel: AuthViewModel,
    modifier: Modifier = Modifier,
    onEditProfileClick: (() -> Unit)? = null,
    onFriendsClick: (() -> Unit)? = null
) {
    val currentUserProfile by authViewModel.currentUserProfile.collectAsState()
    val isLoading by authViewModel.isLoading.collectAsState()
    val errorMessage by authViewModel.errorMessage.collectAsState()
    val unreadNotificationsCount by authViewModel.unreadNotificationsCount.collectAsState()
    val preferences = (LocalContext.current.applicationContext as ZholdasApplication).preferences
    val selectedTheme by preferences.theme.collectAsState(initial = AppTheme.SYSTEM)
    val settingsScope = rememberCoroutineScope()

    var friendsCount by remember { mutableStateOf(0) }
    var pendingRequestsCount by remember { mutableStateOf(0) }
    var isShowingEditProfile by remember { mutableStateOf(false) }
    var isShowingFriendsList by remember { mutableStateOf(false) }
    var isShowingModeratorDashboard by remember { mutableStateOf(false) }
    var languageMenuExpanded by remember { mutableStateOf(false) }

    LaunchedEffect(currentUserProfile, isShowingFriendsList, isShowingEditProfile) {
        val friends = authViewModel.fetchFriends()
        val requests = authViewModel.fetchFriendRequests()
        friendsCount = friends.size
        pendingRequestsCount = requests.size
    }

    if (isShowingEditProfile) {
        EditProfileScreen(
            authViewModel = authViewModel,
            onDismiss = { isShowingEditProfile = false }
        )
        return
    }

    if (isShowingFriendsList) {
        FriendsListScreen(
            authViewModel = authViewModel,
            onBack = { isShowingFriendsList = false }
        )
        return
    }

    if (isShowingModeratorDashboard) {
        ModeratorDashboardScreen(
            authViewModel = authViewModel,
            onBack = { isShowingModeratorDashboard = false }
        )
        return
    }

    val openEditProfile = {
        if (onEditProfileClick != null) {
            onEditProfileClick()
        } else {
            isShowingEditProfile = true
        }
    }

    val openFriendsList = {
        if (onFriendsClick != null) {
            onFriendsClick()
        } else {
            isShowingFriendsList = true
        }
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(ZholdasBackground)
    ) {
        Column(
            modifier = Modifier.fillMaxSize()
        ) {
            // Top Navigation Bar matching ProfileTabView.swift
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp)
                    .padding(horizontal = 16.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Spacer(modifier = Modifier.width(48.dp))

                Text(
                    text = "tab_profile".localized,
                    color = ZholdasTextPrimary,
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold
                )

                TextButton(onClick = openEditProfile) {
                    Text(
                        text = "prof_edit_btn".localized,
                        color = ZholdasAccent,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Medium
                    )
                }
            }

            Divider(color = ZholdasBorder)

            if (isLoading && currentUserProfile == null) {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(16.dp)
                    ) {
                        CircularProgressIndicator(
                            color = ZholdasAccent,
                            modifier = Modifier.size(36.dp)
                        )
                        Text(
                            text = "prof_loading".localized,
                            color = ZholdasTextSecondary,
                            fontSize = 14.sp
                        )
                    }
                }
            } else if (currentUserProfile != null) {
                val profile = currentUserProfile!!
                Column(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxWidth()
                        .verticalScroll(rememberScrollState())
                        .padding(bottom = 88.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Spacer(modifier = Modifier.height(12.dp))

                    // Avatar View
                    AvatarView(profile = profile)

                    Spacer(modifier = Modifier.height(18.dp))

                    // User Info
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Text(
                            text = profile.fullName,
                            color = ZholdasTextPrimary,
                            fontSize = 22.sp,
                            fontWeight = FontWeight.Bold
                        )

                        Text(
                            text = "@${profile.username}",
                            color = ZholdasAccent,
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Medium
                        )

                        if (!profile.city.isNullOrEmpty()) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(4.dp),
                                modifier = Modifier.padding(top = 2.dp)
                            ) {
                                Icon(
                                    imageVector = Icons.Default.Place,
                                    contentDescription = null,
                                    tint = ZholdasTextSecondary,
                                    modifier = Modifier.size(16.dp)
                                )
                                Text(
                                    text = profile.city,
                                    color = ZholdasTextSecondary,
                                    fontSize = 14.sp
                                )
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(18.dp))

                    // Bio Card
                    BioCard(
                        profile = profile,
                        modifier = Modifier.padding(horizontal = 24.dp)
                    )

                    Spacer(modifier = Modifier.height(18.dp))

                    // Statistics Cards
                    StatsSection(
                        profile = profile,
                        friendsCount = friendsCount,
                        pendingRequestsCount = pendingRequestsCount,
                        onFriendsClick = openFriendsList,
                        modifier = Modifier.padding(horizontal = 24.dp)
                    )

                    Spacer(modifier = Modifier.height(18.dp))

                    // Menu & Settings Section
                    SettingsSection(
                        unreadNotificationsCount = unreadNotificationsCount,
                        pendingRequestsCount = pendingRequestsCount,
                        onFriendsClick = openFriendsList,
                        languageMenuExpanded = languageMenuExpanded,
                        onLanguageMenuExpandedChange = { languageMenuExpanded = it },
                        selectedTheme = selectedTheme,
                        onLanguageSelected = { language ->
                            Localization.language = language
                            settingsScope.launch { preferences.setLanguage(language) }
                        },
                        onThemeSelected = { theme ->
                            settingsScope.launch { preferences.setTheme(theme) }
                        },
                        modifier = Modifier.padding(horizontal = 24.dp)
                    )

                    // Moderator Dashboard Button
                    if (profile.role == "moderator" || profile.role == "admin") {
                        Spacer(modifier = Modifier.height(18.dp))
                        ModeratorDashboardButton(
                            role = profile.role,
                            onClick = { isShowingModeratorDashboard = true },
                            modifier = Modifier.padding(horizontal = 24.dp)
                        )
                    }

                    Spacer(modifier = Modifier.height(18.dp))

                    // Sign Out Button
                    SignOutButton(
                        onSignOut = { authViewModel.signOut() },
                        modifier = Modifier.padding(horizontal = 24.dp)
                    )

                    Spacer(modifier = Modifier.height(16.dp))
                }
            } else {
                // Fallback / Error state
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(16.dp),
                        modifier = Modifier.padding(horizontal = 32.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Warning,
                            contentDescription = null,
                            tint = ZholdasAccent,
                            modifier = Modifier.size(48.dp)
                        )
                        Text(
                            text = errorMessage ?: "Не удалось загрузить профиль",
                            color = ZholdasTextPrimary,
                            textAlign = TextAlign.Center,
                            fontSize = 16.sp
                        )

                        Button(
                            onClick = { authViewModel.fetchUserProfile() },
                            colors = ButtonDefaults.buttonColors(containerColor = ZholdasAccent)
                        ) {
                            Text(
                                text = "btn_retry".localized,
                                color = Color.White,
                                fontWeight = FontWeight.Bold
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun AvatarView(profile: User) {
    Box(
        modifier = Modifier
            .size(88.dp)
            .shadow(18.dp, CircleShape, ambientColor = ZholdasAccent.copy(alpha = 0.16f), spotColor = ZholdasAccent.copy(alpha = 0.16f))
            .clip(CircleShape)
            .background(ZholdasElevatedSurface)
            .border(2.dp, ZholdasAccent.copy(alpha = 0.48f), CircleShape),
        contentAlignment = Alignment.Center
    ) {
        if (!profile.avatarURL.isNullOrEmpty()) {
            AsyncImage(
                model = profile.avatarURL,
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .size(88.dp)
                    .clip(CircleShape)
            )
        } else {
            Text(
                text = getInitials(profile.fullName),
                color = Color.White,
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold
            )
        }
    }
}

@Composable
private fun BioCard(
    profile: User,
    modifier: Modifier = Modifier
) {
    val details = parsedProfileDetails(profile.bio)

    ModernCard(modifier = modifier) {
        Text(
            text = "prof_about_me".localized,
            color = ZholdasTextSecondary,
            fontSize = 12.sp,
            fontWeight = FontWeight.Bold,
            letterSpacing = 1.5.sp
        )

        Spacer(modifier = Modifier.height(8.dp))

        if (details.badges.isNotEmpty()) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                details.badges.forEach { badge ->
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(50))
                            .background(ZholdasAccent.copy(alpha = 0.13f))
                            .padding(horizontal = 10.dp, vertical = 6.dp)
                    ) {
                        Text(
                            text = badge,
                            color = ZholdasAccent,
                            fontSize = 12.sp,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                }
            }
            Spacer(modifier = Modifier.height(8.dp))
        }

        Text(
            text = details.bio,
            color = ZholdasTextPrimary.copy(alpha = 0.9f),
            fontSize = 15.sp
        )
    }
}

@Composable
private fun StatsSection(
    profile: User,
    friendsCount: Int,
    pendingRequestsCount: Int,
    onFriendsClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Events Card
        ModernCard(modifier = Modifier.weight(1f)) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier.fillMaxWidth()
            ) {
                Text(
                    text = "${profile.eventsCount ?: 0}",
                    color = ZholdasTextPrimary,
                    fontSize = 20.sp,
                    fontWeight = FontWeight.Bold
                )
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = "prof_events_count".localized,
                    color = ZholdasTextSecondary,
                    fontSize = 12.sp
                )
            }
        }

        // Friends Card (Clickable)
        Box(
            modifier = Modifier
                .weight(1f)
                .clickable { onFriendsClick() }
        ) {
            ModernCard {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        Text(
                            text = "$friendsCount",
                            color = ZholdasTextPrimary,
                            fontSize = 20.sp,
                            fontWeight = FontWeight.Bold
                        )

                        if (pendingRequestsCount > 0) {
                            Box(
                                modifier = Modifier
                                    .clip(RoundedCornerShape(50))
                                    .background(Color.Red)
                                    .padding(horizontal = 6.dp, vertical = 2.dp)
                            ) {
                                Text(
                                    text = "+$pendingRequestsCount",
                                    color = Color.White,
                                    fontSize = 10.sp,
                                    fontWeight = FontWeight.Bold
                                )
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = "prof_friends_count".localized,
                        color = ZholdasTextSecondary,
                        fontSize = 12.sp
                    )
                }
            }
        }

        // Rating Card
        ModernCard(modifier = Modifier.weight(1f)) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier.fillMaxWidth()
            ) {
                val ratingVal = profile.rating ?: 5.0
                Text(
                    text = String.format(Locale.US, "%.1f", ratingVal),
                    color = ZholdasAccent,
                    fontSize = 20.sp,
                    fontWeight = FontWeight.Bold
                )
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = "prof_rating_count".localized,
                    color = ZholdasTextSecondary,
                    fontSize = 12.sp
                )
            }
        }
    }
}

@Composable
private fun SettingsSection(
    unreadNotificationsCount: Int,
    pendingRequestsCount: Int,
    onFriendsClick: () -> Unit,
    languageMenuExpanded: Boolean,
    onLanguageMenuExpandedChange: (Boolean) -> Unit,
    selectedTheme: AppTheme,
    onLanguageSelected: (String) -> Unit,
    onThemeSelected: (AppTheme) -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text(
            text = "prof_menu_and_settings".localized,
            color = ZholdasTextSecondary,
            fontSize = 12.sp,
            fontWeight = FontWeight.Bold,
            letterSpacing = 1.5.sp,
            modifier = Modifier.padding(top = 8.dp)
        )

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .background(ZholdasSurface)
                .border(1.dp, Color.White.copy(alpha = 0.06f), RoundedCornerShape(12.dp))
        ) {
            // 1. Language Toggle
            Box(modifier = Modifier.fillMaxWidth()) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { onLanguageMenuExpandedChange(true) }
                        .padding(horizontal = 16.dp, vertical = 14.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("??", fontSize = 18.sp)
                    Spacer(modifier = Modifier.width(12.dp))
                    Text(
                        text = "prof_lang".localized,
                        color = ZholdasTextPrimary,
                        fontSize = 15.sp
                    )
                    Spacer(modifier = Modifier.weight(1f))
                    val currentLangLabel = when (Localization.language) {
                        "kk" -> "Қазақша"
                        "en" -> "English"
                        else -> "Русский"
                    }
                    Text(
                        text = currentLangLabel,
                        color = ZholdasAccent,
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Medium
                    )
                }

                DropdownMenu(
                    expanded = languageMenuExpanded,
                    onDismissRequest = { onLanguageMenuExpandedChange(false) },
                    modifier = Modifier.background(ZholdasElevatedSurface)
                ) {
                    DropdownMenuItem(
                        text = { Text("Русский", color = Color.White) },
                        onClick = {
                            onLanguageSelected("ru")
                            onLanguageMenuExpandedChange(false)
                        }
                    )
                    DropdownMenuItem(
                        text = { Text("Қазақша", color = Color.White) },
                        onClick = {
                            onLanguageSelected("kk")
                            onLanguageMenuExpandedChange(false)
                        }
                    )
                    DropdownMenuItem(
                        text = { Text("English", color = Color.White) },
                        onClick = {
                            onLanguageSelected("en")
                            onLanguageMenuExpandedChange(false)
                        }
                    )
                }
            }

            Divider(color = ZholdasBorder)

            var themeMenuExpanded by remember { mutableStateOf(false) }
            Box(modifier = Modifier.fillMaxWidth()) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { themeMenuExpanded = true }
                        .padding(horizontal = 16.dp, vertical = 14.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(Icons.Default.Palette, contentDescription = null, tint = ZholdasAccent)
                    Spacer(modifier = Modifier.width(12.dp))
                    Text(
                        when (Localization.language) {
                            "kk" -> "Тақырып"
                            "en" -> "Theme"
                            else -> "Тема"
                        },
                        color = ZholdasTextPrimary,
                        fontSize = 15.sp
                    )
                    Spacer(modifier = Modifier.weight(1f))
                    Text(
                        when (selectedTheme) {
                            AppTheme.SYSTEM -> themeLabel(AppTheme.SYSTEM)
                            AppTheme.LIGHT -> themeLabel(AppTheme.LIGHT)
                            AppTheme.DARK -> themeLabel(AppTheme.DARK)
                        },
                        color = ZholdasAccent,
                        fontSize = 14.sp
                    )
                }
                DropdownMenu(
                    expanded = themeMenuExpanded,
                    onDismissRequest = { themeMenuExpanded = false },
                    modifier = Modifier.background(ZholdasElevatedSurface)
                ) {
                    listOf(
                        AppTheme.SYSTEM to themeLabel(AppTheme.SYSTEM),
                        AppTheme.LIGHT to themeLabel(AppTheme.LIGHT),
                        AppTheme.DARK to themeLabel(AppTheme.DARK)
                    ).forEach { (theme, label) ->
                        DropdownMenuItem(
                            text = { Text(label, color = Color.White) },
                            onClick = {
                                onThemeSelected(theme)
                                themeMenuExpanded = false
                            },
                            trailingIcon = {
                                if (selectedTheme == theme) {
                                    Icon(Icons.Default.Check, contentDescription = null, tint = ZholdasAccent)
                                }
                            }
                        )
                    }
                }
            }

            Divider(color = ZholdasBorder)

            // 2. Notifications & Activity Link
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { }
                    .padding(horizontal = 16.dp, vertical = 14.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = Icons.Default.Notifications,
                    contentDescription = null,
                    tint = ZholdasAccent,
                    modifier = Modifier.size(20.dp)
                )
                Spacer(modifier = Modifier.width(12.dp))
                Text(
                    text = "prof_notifications".localized,
                    color = ZholdasTextPrimary,
                    fontSize = 15.sp
                )
                Spacer(modifier = Modifier.weight(1f))
                if (unreadNotificationsCount > 0) {
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(50))
                            .background(Color.Red)
                            .padding(horizontal = 6.dp, vertical = 2.dp)
                    ) {
                        Text(
                            text = "$unreadNotificationsCount",
                            color = Color.White,
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }
                    Spacer(modifier = Modifier.width(8.dp))
                }
                Text(">", color = ZholdasTextSecondary)
            }

            Divider(color = ZholdasBorder)

            // 3. My Events Link
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { }
                    .padding(horizontal = 16.dp, vertical = 14.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = Icons.Default.DateRange,
                    contentDescription = null,
                    tint = ZholdasAccent,
                    modifier = Modifier.size(20.dp)
                )
                Spacer(modifier = Modifier.width(12.dp))
                Text(
                    text = "prof_my_events".localized,
                    color = ZholdasTextPrimary,
                    fontSize = 15.sp
                )
                Spacer(modifier = Modifier.weight(1f))
                Text(">", color = ZholdasTextSecondary)
            }

            Divider(color = ZholdasBorder)

            // 4. Friends List Link
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { onFriendsClick() }
                    .padding(horizontal = 16.dp, vertical = 14.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = Icons.Default.Person,
                    contentDescription = null,
                    tint = ZholdasAccent,
                    modifier = Modifier.size(20.dp)
                )
                Spacer(modifier = Modifier.width(12.dp))
                Text(
                    text = "prof_friends_list".localized,
                    color = ZholdasTextPrimary,
                    fontSize = 15.sp
                )
                Spacer(modifier = Modifier.weight(1f))
                if (pendingRequestsCount > 0) {
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(50))
                            .background(Color.Red)
                            .padding(horizontal = 6.dp, vertical = 2.dp)
                    ) {
                        Text(
                            text = "+$pendingRequestsCount",
                            color = Color.White,
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }
                    Spacer(modifier = Modifier.width(8.dp))
                }
                Text(">", color = ZholdasTextSecondary)
            }
        }
    }
}

private fun themeLabel(theme: AppTheme): String = when (Localization.language) {
    "kk" -> when (theme) {
        AppTheme.SYSTEM -> "Жүйелік"
        AppTheme.LIGHT -> "Жарық"
        AppTheme.DARK -> "Қараңғы"
    }
    "en" -> when (theme) {
        AppTheme.SYSTEM -> "System"
        AppTheme.LIGHT -> "Light"
        AppTheme.DARK -> "Dark"
    }
    else -> when (theme) {
        AppTheme.SYSTEM -> "Системная"
        AppTheme.LIGHT -> "Светлая"
        AppTheme.DARK -> "Тёмная"
    }
}

@Composable
private fun ModeratorDashboardButton(
    role: String?,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(ZholdasAccent)
            .clickable { onClick() }
            .padding(vertical = 14.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = Icons.Default.Shield,
            contentDescription = null,
            tint = Color.White,
            modifier = Modifier.size(20.dp)
        )
        Spacer(modifier = Modifier.width(8.dp))
        Text(
            text = if (role == "admin") "prof_admin_panel".localized else "prof_moderator_panel".localized,
            color = Color.White,
            fontWeight = FontWeight.Bold,
            fontSize = 16.sp
        )
    }
}

@Composable
private fun SignOutButton(
    onSignOut: () -> Unit,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(ZholdasDanger.copy(alpha = 0.12f))
            .border(1.dp, ZholdasDanger.copy(alpha = 0.28f), RoundedCornerShape(12.dp))
            .clickable { onSignOut() }
            .padding(vertical = 14.dp),
        contentAlignment = Alignment.Center
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center
        ) {
            Icon(
                imageVector = Icons.AutoMirrored.Filled.ExitToApp,
                contentDescription = null,
                tint = ZholdasDanger,
                modifier = Modifier.size(20.dp)
            )
            Spacer(modifier = Modifier.width(8.dp))
            Text(
                text = "prof_signout".localized,
                color = ZholdasDanger,
                fontWeight = FontWeight.Bold,
                fontSize = 16.sp
            )
        }
    }
}

data class ParsedBio(val bio: String, val badges: List<String>)

private fun parsedProfileDetails(rawBio: String?): ParsedBio {
    val cleanRaw = rawBio?.trim() ?: ""
    if (cleanRaw.isEmpty()) {
        return ParsedBio("prof_default_bio".localized, emptyList())
    }

    var cleanedBio = cleanRaw
    val badges = mutableListOf<String>()

    val gender = extractProfileMetadata("gender", cleanRaw)
    if (gender != null) {
        badges.add(gender)
        cleanedBio = cleanedBio.replace("[gender:$gender]", "")
    }

    val birthYear = extractProfileMetadata("birth_year", cleanRaw)
    if (birthYear != null) {
        badges.add(ageBadge(birthYear))
        cleanedBio = cleanedBio.replace("[birth_year:$birthYear]", "")
    }

    cleanedBio = cleanedBio.trim()
    if (cleanedBio.isEmpty()) {
        cleanedBio = "prof_default_bio".localized
    }

    return ParsedBio(cleanedBio, badges)
}

private fun extractProfileMetadata(key: String, text: String): String? {
    val prefix = "[$key:"
    val start = text.indexOf(prefix)
    if (start == -1) return null
    val valueStart = start + prefix.length
    val end = text.indexOf("]", valueStart)
    if (end == -1) return null
    val value = text.substring(valueStart, end).trim()
    return value.ifEmpty { null }
}

private fun ageBadge(birthYear: String): String {
    val year = birthYear.toIntOrNull() ?: return birthYear
    if (year <= 1900) return birthYear
    val currentYear = Calendar.getInstance().get(Calendar.YEAR)
    val age = (currentYear - year).coerceAtLeast(0)
    return "$age ${"reg_age_suffix".localized}"
}

private fun getInitials(name: String): String {
    val parts = name.trim().split(" ").filter { it.isNotEmpty() }
    return when {
        parts.size >= 2 -> "${parts[0].take(1)}${parts[1].take(1)}".uppercase()
        parts.isNotEmpty() -> parts[0].take(2).uppercase()
        else -> "??"
    }
}
