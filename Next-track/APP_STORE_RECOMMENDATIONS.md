# Next Track - App Store Publishing Recommendations

## Current State Summary
The app has **solid core functionality** (tracking, geofencing, export, battery optimization) but is **~30% ready** for App Store submission. Major gaps exist in UI polish, legal requirements, and accessibility.

---

## CRITICAL BLOCKERS (Must Fix for App Store)

### 1. Launch Screen
- **Status:** Empty `<dict/>` in Info.plist - shows blank screen on launch
- **Fix:** Create SwiftUI launch screen with app logo and name
- **File:** Create `LaunchScreen.swift` or use Info.plist configuration

### 2. App Icons - Incomplete
- **Status:** Only 1024x1024 universal icon exists
- **Fix:** Generate all required sizes (180x180, 167x167, 152x152, 120x120, 87x87, 80x80, 58x58, 40x40)
- **File:** `Resources/Assets.xcassets/AppIcon.appiconset/`

### 3. Security - NSAllowsArbitraryLoads
- **Status:** Set to `true` - allows insecure HTTP connections
- **Fix:** Remove or add domain-specific exceptions for Nextcloud servers
- **File:** `Resources/Info.plist`

### 4. No Onboarding Flow
- **Status:** App jumps directly to MainView, requests permissions immediately
- **Fix:** Add welcome screens explaining app purpose before permission requests
- **Files:** Create `Views/OnboardingView.swift`

### 5. Missing Legal Documents
- **Status:** No Privacy Policy or Terms of Service
- **Fix:** Create in-app privacy policy screen + host online
- **Files:** Create `Views/PrivacyPolicyView.swift`, `Views/TermsView.swift`

### 6. Accessibility - Zero VoiceOver Support
- **Status:** No accessibilityLabel, accessibilityHint, or accessibilityValue anywhere
- **Fix:** Add accessibility modifiers to all interactive elements
- **Files:** All view files need accessibility additions

---

## HIGH PRIORITY (Should Fix Before Release)

### 7. User-Facing Error Handling
- **Status:** Errors logged to console but not shown to users
- **Fix:** Add toast/banner system for errors and confirmations
- **Files:** Create `Views/Components/ToastView.swift`, modify service callbacks

### 8. Permission Explanation Screens
- **Status:** Permissions requested without context
- **Fix:** Show explanation screen BEFORE each permission request
- **Files:** Modify `NextTrackApp.swift`, create permission explanation views

### 9. Input Validation
- **Status:** Settings can have invalid values (0 interval, negative accuracy)
- **Fix:** Add bounds checking and validation feedback
- **Files:** `Models/TrackingSettings.swift`, `Views/SettingsView.swift`

### 10. Loading States
- **Status:** Minimal - only ProgressView in some places
- **Fix:** Add consistent loading indicators for async operations
- **Files:** All views with network/async operations

### 11. Network Connectivity Indicator
- **Status:** Status shown in Stats tab but not persistently visible
- **Fix:** Add persistent indicator in header when offline
- **Files:** `Views/CustomTitleHeaderView.swift`

---

## MEDIUM PRIORITY (Polish)

### 12. Localization Infrastructure
- **Status:** 100+ hardcoded English strings
- **Fix:** Create Localizable.strings and use NSLocalizedString
- **Files:** Create `Resources/Localizable.strings`, update all views

### 13. App Icon Badge
- **Status:** Not implemented
- **Fix:** Show pending location count on app icon
- **Files:** `Services/PendingLocationQueue.swift`, App lifecycle

### 14. Keyboard Handling
- **Status:** No explicit dismissal handling in forms
- **Fix:** Add keyboard dismissal gestures and toolbar
- **Files:** Views with text inputs

### 15. Help/Documentation
- **Status:** Minimal in-app help
- **Fix:** Add help screens or tooltips for complex features
- **Files:** Create `Views/HelpView.swift`

### 16. Settings Backup/Export
- **Status:** Server config not exportable
- **Fix:** Add ability to export/import app configuration
- **Files:** `Services/SettingsManager.swift`, `Views/SettingsView.swift`

---

## NICE TO HAVE (Future Enhancements)

### 17. Widget Extension
- Show tracking status on home screen
- Quick toggle tracking

### 18. Watch App
- View tracking status
- Start/stop tracking from wrist

### 19. Siri Shortcuts
- "Start tracking"
- "Stop tracking"
- "Export today's data"

### 20. Secure Credential Storage
- Move server token to Keychain instead of UserDefaults

### 21. iCloud Sync
- Sync settings across devices

---

## UI/UX IMPROVEMENTS

### Visual Enhancements
1. **Standardize corner radius** - Currently mixed 12pt/16pt
2. **Consistent spacing system** - Define 4pt, 8pt, 12pt, 16pt, 24pt
3. **Add subtle animations** - Improve state transitions
4. **Empty state illustrations** - Add graphics to empty states

### Navigation Improvements
1. **Deep linking** - Allow URL scheme to open specific views
2. **Quick actions** - 3D Touch shortcuts to start/stop tracking

### Map Enhancements
1. **Session selection on map** - Tap to highlight specific session
2. **Heat map mode** - Show frequently visited areas
3. **Path smoothing** - Reduce GPS noise in displayed paths

---

## IMPLEMENTATION PRIORITY ORDER

### Phase 1: App Store Blockers (Week 1)
1. Create launch screen
2. Generate all app icon sizes
3. Fix NSAllowsArbitraryLoads
4. Add basic onboarding (3 screens)
5. Create Privacy Policy view
6. Add accessibility labels to buttons/controls

### Phase 2: Core Polish (Week 2)
7. Implement toast/error system
8. Add permission explanation screens
9. Input validation with feedback
10. Loading state improvements
11. Persistent connectivity indicator

### Phase 3: Enhancement (Week 3)
12. Localization setup (at least structure)
13. App icon badge
14. Keyboard handling
15. Basic help documentation

### Phase 4: Submission Prep (Week 4)
- App Store screenshots
- App description and keywords
- Privacy policy hosted URL
- Final testing on multiple devices
- Submit for review

---

## FILES TO CREATE

| File | Purpose |
|------|---------|
| `Views/OnboardingView.swift` | Welcome and setup flow |
| `Views/PrivacyPolicyView.swift` | In-app privacy policy |
| `Views/Components/ToastView.swift` | Error/success notifications |
| `Views/HelpView.swift` | Feature documentation |
| `Resources/Localizable.strings` | Localization strings |
| `Resources/LaunchScreen.storyboard` | Launch screen (or SwiftUI) |

## FILES TO MODIFY

| File | Changes |
|------|---------|
| `Resources/Info.plist` | Fix ATS, launch screen config |
| `Resources/Assets.xcassets/AppIcon.appiconset/` | Add all icon sizes |
| `App/NextTrackApp.swift` | Add onboarding flow, permission timing |
| `Views/MainView.swift` | Accessibility, error handling |
| `Views/SettingsView.swift` | Validation, accessibility |
| `Views/StatsHistoryView.swift` | Accessibility, loading states |
| `Views/MapPreviewView.swift` | Accessibility |
| `Views/GeofenceSettingsView.swift` | Accessibility, validation |
| `Views/CustomTitleHeaderView.swift` | Offline indicator |
| `Models/TrackingSettings.swift` | Validation logic |

---

## ESTIMATED EFFORT

| Category | Items | Effort |
|----------|-------|--------|
| Critical Blockers | 6 | 3-4 days |
| High Priority | 5 | 2-3 days |
| Medium Priority | 5 | 2-3 days |
| Nice to Have | 5 | Future releases |

**Total for App Store Ready:** ~2-3 weeks
