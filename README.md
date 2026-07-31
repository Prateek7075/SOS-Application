# Emergency SOS App

A personal emergency SOS mobile application built with **Flutter**, **Laravel**, **MySQL**, and **Firebase Authentication**.

The app allows a user to start an emergency SOS alert, send SMS messages to trusted contacts, share live location updates, and provide a public tracking page where emergency contacts can view the user's latest location on a browser-based map.

This project is an Android-focused emergency assistance MVP with offline-first local storage, Laravel APIs, Firebase authentication, native Android SMS, native foreground location tracking, and a public live tracking page.

---

## Repository Description

A Flutter + Laravel emergency SOS mobile app that sends SMS alerts with live location tracking, trusted contacts, emergency profile details, Firebase authentication, offline fallback, local caching, and a public live tracking page with a moving map marker.

---

## Platform Support

This version is built and tested for **Android**.

The app uses Android-specific features such as:

- Native SMS sending
- Android foreground location service
- Android runtime permissions
- Android battery optimization checks
- Android home screen widget / app shortcut support
- APK installation and testing

**iOS support is not included** in the current version.

---

## Features

### Authentication

- Firebase Email/Password login and registration
- Firebase user synced with Laravel backend
- User-specific profile, contacts, SOS data, and local cache using Firebase UID

### Emergency Profile

Users can save important emergency details:

- Full name
- Phone number
- Blood group
- Emergency relative name
- Emergency relative phone
- Address

Profile data uses an offline-first approach:

- Saved locally on the phone
- Synced with Laravel when internet is available
- Fetched from Laravel when online
- Uses local storage when offline
- Pending local profile changes sync later when backend/internet becomes available

### Trusted Contacts

- Add trusted contacts manually
- Import trusted contacts from phone contacts
- Contacts are saved in Laravel
- Contacts are cached locally using user-specific local storage
- Contacts can be loaded instantly from local cache
- Backend refresh updates the local cache when internet is available

### SOS History

SOS history uses a fast local-first loading flow:

- Cached SOS history is shown instantly from local storage
- Backend history API is called in the background
- Latest backend history replaces the local cache
- History remains visible when internet is slow or unavailable
- Updated statuses such as `active`, `cancelled`, and `expired` are refreshed from backend

### SOS Alert

- Long press SOS button to start an emergency alert
- Active SOS state persists even if the app is closed or reopened
- Existing active SOS is detected before starting a new SOS
- User can continue existing SOS or cancel it and start a new one
- SOS can be cancelled from the Active SOS screen or Home screen
- Logout is blocked while SOS is active

### SMS Alert

When SOS starts, the app sends SMS messages to trusted contacts.

The SMS includes:

- User name
- User phone number
- Blood group
- Emergency relative details
- Address
- Current location
- Battery percentage
- Live tracking link when available

SMS is sent using the phone's SIM through Android native SMS.

### Offline SOS Fallback

If internet is not available when SOS starts:

- SOS is saved locally as an offline SOS event
- SMS fallback is sent to trusted contacts with current location
- App keeps checking for internet
- When internet returns, offline SOS is converted to live tracking
- Live tracking link is created and sent to contacts

### Live Location Tracking

- Android foreground service sends live location updates
- Flutter fallback timer also attempts location updates while screen is active
- Location updates are sent every 30 seconds
- Backend stores location updates in `sos_location_updates`
- Location update API is protected using an SOS tracking token
- Failed location updates are saved locally for retry
- Background service heartbeat helps detect whether native tracking is still alive
- Active SOS monitor can restart the native foreground service if needed

### Automatic Safety Check

While SOS is active, the app automatically checks important readiness items:

- Location permission
- GPS/location service status
- SMS permission
- Notification permission
- Trusted contacts availability
- Emergency profile completeness
- Internet status
- Battery optimization status
- Native background tracking heartbeat

The app shows safety warnings if any important check may affect SOS reliability.

### Battery Optimization Handling

The app checks Android battery optimization status and warns the user if the phone may restrict background tracking.

Users can open battery settings directly from the app.

### Public Tracking Page

Emergency contacts can open the tracking link in any browser.

The tracking page shows:

- SOS status
- Tracking health
- Emergency profile details
- Latest latitude and longitude
- GPS accuracy
- Battery percentage
- Last updated time
- Link expiry time
- Live moving map marker
- Accuracy circle
- Google Maps button
- Call user button
- Call emergency relative button

The map uses:

- MapLibre GL JS
- OpenStreetMap raster tiles
- Esri satellite tiles
- CARTO labels
- OpenTopoMap terrain tiles

No Google Maps API key is required for the live tracking map.

### Tracking Link Expiry

Tracking links expire after 24 hours for privacy.

When a tracking link expires:

- SOS status is changed to `expired`
- Final/latest location is saved into `sos_events`
- Native service receives expiry response and stops tracking
- Public tracking API returns expired response

---

## Tech Stack

### Mobile App

- Flutter
- Dart
- Firebase Auth
- SharedPreferences
- Geolocator
- Permission Handler
- Flutter Contacts
- Native Android Kotlin foreground service
- Native Android SMS Manager
- Android WorkManager recovery

### Backend

- Laravel
- PHP
- MySQL
- Firebase Admin SDK
- REST APIs
- Artisan command for cleanup

### Tracking Page

- Laravel Blade
- JavaScript
- MapLibre GL JS
- OpenStreetMap / raster map providers

### Deployment / Testing

- Local Laravel backend for development
- Cloudflare Tunnel for local mobile testing
- Render or permanent backend URL for deployed testing/production

---

## Project Structure

```text
SOS-APP/
├── backend/
│   ├── app/
│   │   ├── Console/Commands/
│   │   ├── Http/Controllers/Api/V1/
│   │   └── Models/
│   ├── database/
│   ├── routes/
│   ├── resources/views/
│   ├── public/css/
│   ├── public/js/
│   └── .env
│
├── mobile/
│   ├── lib/
│   │   ├── config/
│   │   ├── models/
│   │   ├── screens/
│   │   └── services/
│   │
│   └── android/
│       └── app/src/main/kotlin/
│
└── tools/
    └── cloudflared.exe
```

---

## Main App Flow

```text
User registers/logs in
        ↓
User fills emergency profile
        ↓
User adds/imports trusted contacts
        ↓
User long-presses SOS button
        ↓
Flutter creates SOS event in Laravel
        ↓
App sends SMS to trusted contacts
        ↓
Android foreground service starts
        ↓
Phone sends location every 30 seconds
        ↓
Laravel stores live location updates
        ↓
Emergency contact opens tracking link
        ↓
Tracking page shows live moving map marker
```

---

## Offline SOS Flow

```text
User starts SOS without internet
        ↓
App gets current location
        ↓
App sends SMS fallback to trusted contacts
        ↓
Offline SOS is saved locally
        ↓
App checks internet every 30 seconds
        ↓
Internet returns
        ↓
Offline SOS is converted to live SOS
        ↓
Tracking link is created
        ↓
Live tracking SMS is sent to contacts
```

---

## Local Storage Strategy

The app uses local storage to improve speed and offline reliability.

```text
Emergency profile   → Local cache + backend sync
Trusted contacts    → Local cache + backend sync
Active SOS session  → Local storage for resume/recovery
Offline SOS events  → Local storage until internet returns
Failed locations    → Local retry queue
SOS history         → Local cache + backend refresh
Custom SOS message  → Local storage
```

Local data is user-specific wherever required, using the Firebase user UID.

---

## Database Tables

Main tables used:

```text
users
user_profiles
emergency_contacts
sos_events
sos_location_updates
```

### users

Stores main user identity:

```text
id
firebase_uid
name
email
phone
password
created_at
updated_at
```

### user_profiles

Stores emergency profile details:

```text
id
user_id
blood_group
relative_name
relative_phone
address
created_at
updated_at
```

### emergency_contacts

Stores trusted contacts:

```text
id
user_id
name
phone
relationship
has_app
fcm_token
created_at
updated_at
```

### sos_events

Stores SOS sessions:

```text
id
user_id
status
initial_latitude
initial_longitude
tracking_token
network_mode
expires_at
cancelled_at
final_latitude
final_longitude
final_location_updated_at
created_at
updated_at
```

Common SOS statuses:

```text
active
cancelled
expired
offline_sms
```

### sos_location_updates

Stores live location updates:

```text
id
sos_event_id
latitude
longitude
accuracy
battery_percentage
created_at
```

---

## Backend Setup

Go to the backend folder:

```bash
cd backend
```

Install Laravel dependencies:

```bash
composer install
```

Create `.env` file:

```bash
cp .env.example .env
```

Generate Laravel app key:

```bash
php artisan key:generate
```

Configure database in `.env`:

```env
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=sos_app
DB_USERNAME=root
DB_PASSWORD=
```

Run migrations:

```bash
php artisan migrate
```

Start Laravel backend locally:

```bash
php artisan serve --host=127.0.0.1 --port=8000
```

Test backend:

```text
http://127.0.0.1:8000/api/test
```

Expected response:

```json
{
  "success": true,
  "message": "SOS backend API is working"
}
```

---

## Firebase Setup

This app uses Firebase Authentication.

Enable Email/Password authentication in Firebase Console.

Download Firebase Admin SDK service account JSON and place it here:

```text
backend/storage/app/firebase/service-account.json
```

Add this in backend `.env`:

```env
FIREBASE_CREDENTIALS=storage/app/firebase/service-account.json
```

Important:

```text
Do not commit service-account.json to GitHub.
```

Add this in `.gitignore`:

```text
/storage/app/firebase/service-account.json
```

---

## Cloudflare Tunnel Setup For Local Testing

For local testing, the mobile app can connect to the local Laravel backend through Cloudflare Tunnel.

Keep Laravel running first, then open a new terminal from the project root:

```bash
tools/cloudflared.exe tunnel --url http://127.0.0.1:8000
```

Cloudflare will generate a public URL like:

```text
https://example-random-url.trycloudflare.com
```

This URL must be added in the Flutter app config.

Cloudflare quick tunnel URLs change whenever the tunnel restarts.

So when a new Cloudflare URL is generated:

```text
Update app_config.dart
Rebuild or rerun the Flutter app
```

---

## Flutter App Setup

Go to the Flutter app folder:

```bash
cd mobile
```

Install Flutter dependencies:

```bash
flutter pub get
```

Update backend URL in:

```text
mobile/lib/config/app_config.dart
```

Example for Cloudflare/local testing:

```dart
class AppConfig {
  static const String backendBaseUrl =
      'https://your-cloudflare-url.trycloudflare.com';

  static const String apiBaseUrl = '$backendBaseUrl/api/v1';
}
```

Example for deployed backend:

```dart
class AppConfig {
  static const String backendBaseUrl =
      'https://your-backend-domain.com';

  static const String apiBaseUrl = '$backendBaseUrl/api/v1';
}
```

Important:

```text
Do not add a slash at the end of backendBaseUrl.
```

Correct:

```dart
'https://abc.trycloudflare.com'
```

Wrong:

```dart
'https://abc.trycloudflare.com/'
```

Run the app:

```bash
flutter run
```

Run in profile mode for performance testing:

```bash
flutter run --profile
```

Build debug APK:

```bash
flutter build apk --debug
```

Build release APK:

```bash
flutter build apk --release
```

APK location:

```text
mobile/build/app/outputs/flutter-apk/app-release.apk
```

---

## Running On A Real Android Phone

Enable Developer Options on Android phone:

```text
Settings
→ About phone
→ Tap Build number 7 times
```

Enable USB debugging:

```text
Settings
→ Developer options
→ USB debugging
```

Connect the phone to the laptop and check devices:

```bash
flutter devices
```

Run app on phone:

```bash
flutter run
```

Or install the generated APK manually:

```text
mobile/build/app/outputs/flutter-apk/app-release.apk
```

---

## Required Android Permissions

Allow these permissions on the phone when asked:

```text
Location
SMS
Contacts
Notifications
```

For real SOS SMS testing, the phone must have:

```text
Active SIM card
SMS balance or SMS pack
Mobile network signal
Internet connection
```

---

## Android Permissions Used

The app uses these Android permissions:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

<uses-permission android:name="android.permission.SEND_SMS" />
<uses-permission android:name="android.permission.READ_CONTACTS" />

<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />

<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

---

## Important API Endpoints

### Auth

```text
POST /api/v1/auth/sync-user
GET  /api/v1/users/me
```

### User Profile

```text
GET /api/v1/user-profile
PUT /api/v1/user-profile
```

### Emergency Contacts

```text
GET    /api/v1/emergency-contacts
POST   /api/v1/emergency-contacts
DELETE /api/v1/emergency-contacts/{id}
```

### SOS

```text
POST /api/v1/sos/start
POST /api/v1/sos/{id}/cancel
GET  /api/v1/sos/active
GET  /api/v1/sos/history
POST /api/v1/sos/{id}/location
```

### Public Tracking

```text
GET /api/v1/public/track/{trackingToken}
GET /track/{trackingToken}
```

---

## Cleanup Command

The backend includes an Artisan command to clean old SOS location updates.

```bash
php artisan sos:cleanup-location-updates --hours=24
```

What it does:

```text
1. Finds old cancelled / expired / offline SMS SOS events
2. Saves the latest location into sos_events as final location
3. Deletes old rows from sos_location_updates
```

This keeps the database small while preserving the final known SOS location for history.

For manual testing:

```bash
php artisan sos:cleanup-location-updates --hours=1
```

Note:

```text
If --hours is less than 1, the command should fall back to 24 hours.
```

---

## Performance Notes

The app uses several optimizations for smoother performance:

- Local-first loading for profile, contacts, and SOS history
- Active SOS countdown updated using lightweight state updates
- Backend refresh runs in background where possible
- Reduced unnecessary full-screen rebuilds
- Background location handled natively on Android
- Failed location updates retried instead of blocking UI

For real performance testing, use:

```bash
flutter run --profile
```

or test the release APK:

```bash
flutter build apk --release
```

---

## Security Notes

Implemented:

- Firebase protected user APIs
- User-specific trusted contacts
- User-specific profile
- User-specific SOS history
- SOS location update protected using tracking token
- Public tracking page uses a random tracking token
- Tracking link expiry after 24 hours
- Logout blocked during active SOS
- Local data separated by Firebase UID where required

Not included yet:

- Push notifications
- Admin panel
- End-to-end encryption
- Play Store release
- Full production monitoring

---

## Current Limitations

- Android only
- SMS depends on SIM, signal, permission, and SMS balance
- Background tracking reliability can still depend on Android battery restrictions
- iOS support is not included
- This app is an emergency assistance tool, not a replacement for official emergency services

---

## Roadmap

Planned improvements:

```text
Improve background tracking reliability further
Add push notifications
Add emergency alert dashboard
Add admin panel
Add Play Store readiness
Add production monitoring
Improve UI polish and accessibility
Add better automated testing
```

---

## GitHub Topics

```text
flutter
laravel
firebase-auth
mysql
emergency-sos
live-tracking
android
sms
location-tracking
openstreetmap
maplibre
foreground-service
sharedpreferences
```

---

## Suggested Commit Message

```text
Update SOS app README with offline cache and tracking improvements
```

---

## Disclaimer

This app is an emergency assistance tool built for learning and MVP testing.

It should not be treated as a replacement for official emergency services.

Always contact local emergency services directly in real emergencies.
