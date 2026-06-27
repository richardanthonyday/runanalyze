# RunAnalyze (MVP) - Notes

This initial commit scaffolds a minimal Flutter app and an SDD file describing the MVP. What's next:

- Expand the SDD with detailed UI wireframes and acceptance tests.
- Use Copilot to implement unit and widget tests based on the SDD.
- Add persistence (sqflite) and GPX/TCX import for real workouts.

To run locally:
- Install Flutter SDK: https://flutter.dev/docs/get-started/install
- From this repo root: `flutter pub get`
- Run on an Android Pixel 10 (connected or emulator): `flutter run -d <device-id>`

---

## MVP Test Plan - Happy Path Scenarios

### 1. API Integration & Data Loading

#### Test 1.1: Successful Runalyze API Connection
- **Setup:** User is authenticated with valid Runalyze API token
- **Action:** App launches and requests latest activities
- **Expected:** 
  - API returns list of activities (status 200)
  - Dashboard displays most recent run first
  - No error messages shown
- **Data Displayed:** Activity date, distance, duration, pace, sport type, HR metrics

#### Test 1.2: Empty Activity List
- **Setup:** User has no activities in Runalyze
- **Action:** App fetches activities
- **Expected:**
  - Graceful empty state message displayed
  - No crashes or blank screens
  - Prompt to "Start your first run" or similar

### 2. Dashboard Display

#### Test 2.1: Activity Card Rendering
- **Setup:** Dashboard has loaded 1+ activities
- **Action:** User views activity card
- **Expected:**
  - Card displays: date/time, distance, duration, pace
  - Card displays: average HR, max HR (if available)
  - Sport type icon/label is visible
  - Cards are sorted newest → oldest

#### Test 2.2: Activity List Scrolling
- **Setup:** Dashboard has 5+ activities
- **Action:** User scrolls through list
- **Expected:**
  - All activities are scrollable
  - No UI lag or jank
  - Loading state (spinner) shown while fetching more if pagination used

### 3. Activity Detail View

#### Test 3.1: Open Activity Detail
- **Setup:** Dashboard is loaded with activities
- **Action:** User taps an activity card
- **Expected:**
  - Detail screen opens
  - Full activity metrics displayed: distance, duration, pace, HR (avg/max), power, elevation, temperature, weather
  - Back button visible and functional
  - No data loss or reload

#### Test 3.2: Return to Dashboard
- **Setup:** User is on activity detail screen
- **Action:** User taps back button
- **Expected:**
  - Returns to dashboard
  - Dashboard state preserved (scroll position, list intact)
  - No re-fetch of activities

### 4. Data Persistence

#### Test 4.1: Offline Access (Cache)
- **Setup:** App has loaded activities; network is disabled
- **Action:** App is closed and reopened
- **Expected:**
  - Activities still visible from cache
  - "Offline mode" indicator shown (if implemented)
  - No error messages

#### Test 4.2: Manual Refresh
- **Setup:** Dashboard is displayed
- **Action:** User taps refresh button
- **Expected:**
  - Spinner shown during fetch
  - Latest activities retrieved from API
  - List updates with new/modified activities
  - Spinner dismisses on success

### 5. Error Handling (Basic)

#### Test 5.1: Network Timeout
- **Setup:** Network is slow or unavailable
- **Action:** App attempts to fetch activities
- **Expected:**
  - Error message shown: "Unable to connect. Check your internet."
  - Retry button visible
  - App does not crash

#### Test 5.2: Invalid API Token
- **Setup:** Stored API token is expired or invalid
- **Action:** App fetches activities
- **Expected:**
  - Error message: "Authentication failed. Please log in again."
  - User is prompted to re-authenticate
  - No activity data displayed

---

## Test Execution Checklist

- [ ] All Happy Path scenarios pass
- [ ] No crashes or unhandled exceptions
- [ ] UI is responsive (no ANR/jank)
- [ ] Data displays correctly from API
- [ ] Local cache persists between app closes
- [ ] Error messages are user-friendly
- [ ] Back navigation works as expected
