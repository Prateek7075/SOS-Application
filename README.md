# Emergency SOS App

A personal emergency SOS mobile application built with **Flutter**, **Laravel**, **MySQL**, and **Firebase Authentication**.

The app allows a user to start an SOS alert, automatically send SMS messages to trusted contacts, share live location updates, and provide a public tracking page where emergency contacts can view the user's latest location on a live map.

This project is built as a working **V1 MVP** and has been tested on a real Android phone.

---

## Platform Support

This V1 version is built and tested for Android only.

The app uses Android-specific features such as:

- Native SMS sending
- Android foreground location service
- Android runtime permissions
- APK installation and testing

iOS support is not included.

---

## Repository Description

A Flutter + Laravel emergency SOS mobile app that sends SMS alerts with live location tracking, trusted contacts, emergency profile details, Firebase authentication, and a public live tracking page with a moving map marker.

---

## Features

### Authentication

- Firebase Email/Password login and registration
- Firebase user synced with Laravel backend
- User-specific data using Firebase UID

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
- Contacts are cached locally
- Contacts are user-specific

### SOS Alert

- Long press SOS button to start emergency alert
- Active SOS state persists even if the app is closed or reopened
- SOS can be cancelled
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
- Live tracking link

SMS is sent using the phone's SIM through Android native SMS.

### Live Location Tracking

- Android foreground service sends live location updates
- Location updates are sent every 15 seconds
- Backend stores all location updates
- Location update API is protected using an SOS tracking token
- Public tracking link shows the latest location

### Public Tracking Page

Emergency contacts can open the tracking link in any browser.

The tracking page shows:

- SOS status
- Emergency profile details
- Live moving map marker
- Latest latitude and longitude
- Last updated time
- Google Maps button
- Call user button
- Call emergency relative button
- Call emergency number button

The map uses:

- Leaflet
- OpenStreetMap

No Google Maps API key is required for the live map page.

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

### Backend

- Laravel
- PHP
- MySQL
- Firebase Admin SDK
- REST APIs

### Tracking Page

- Laravel Blade
- JavaScript
- Leaflet
- OpenStreetMap

### Testing Tunnel

- Cloudflare Tunnel

---

## Project Structure

```text
SOS-APP/
├── backend/
│   ├── app/
│   ├── database/
│   ├── routes/
│   ├── resources/views/
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
Phone sends location every 15 seconds
        ↓
Laravel stores live location updates
        ↓
Emergency contact opens tracking link
        ↓
Tracking page shows live moving map marker
```

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
created_at
updated_at
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

## Getting Started

This project has two main parts:

```text
backend/  → Laravel API + MySQL backend
mobile/   → Flutter Android mobile app
```

For V1 testing, the Laravel backend runs locally on the laptop and is exposed to the mobile app using Cloudflare Tunnel.

---

## Prerequisites

Before running the project, make sure these are installed:

```text
Flutter SDK
Android Studio
PHP
Composer
MySQL
Firebase project
Cloudflare Tunnel
```

---

## 1. Backend Setup

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

Start Laravel backend:

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

## 2. Firebase Setup

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

## 3. Cloudflare Tunnel Setup

For V1, the mobile app connects to the local Laravel backend through Cloudflare Tunnel.

Keep Laravel running first, then open a new terminal from the project root:

```bash
tools/cloudflared.exe tunnel --url http://127.0.0.1:8000
```

Cloudflare will generate a public URL like:

```text
https://example-random-url.trycloudflare.com
```

This URL must be added in the Flutter app config.

---

## 4. Flutter App Setup

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

Example:

```dart
class AppConfig {
  static const String backendBaseUrl =
      'https://your-cloudflare-url.trycloudflare.com';

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

Build debug APK:

```bash
flutter build apk --debug
```

APK location:

```text
mobile/build/app/outputs/flutter-apk/app-debug.apk
```

---

## 5. Running on a Real Android Phone

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
mobile/build/app/outputs/flutter-apk/app-debug.apk
```

---

## 6. Required Android Permissions

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

## 7. V1 Running Requirement

This V1 version requires the backend to be running locally.

For the app to work fully:

```text
Laravel backend must be running
Cloudflare tunnel must be running
Cloudflare URL must match app_config.dart
```

Cloudflare quick tunnel URLs change whenever the tunnel restarts.

So when a new Cloudflare URL is generated:

```text
Update app_config.dart
Rebuild or rerun the Flutter app
```

For production use, the Laravel backend should be deployed to a permanent server/domain.

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
GET  /api/v1/sos/history
POST /api/v1/sos/{id}/location
```

### Public Tracking

```text
GET /api/v1/public/track/{trackingToken}
GET /track/{trackingToken}
```

---

## Security Notes

Implemented in V1:

- Firebase protected user APIs
- User-specific trusted contacts
- User-specific profile
- User-specific SOS history
- SOS location update protected using tracking token
- Public tracking page uses a random tracking token
- Logout blocked during active SOS

Not included in V1:

- Permanent backend deployment
- Push notifications
- Admin panel
- End-to-end encryption
- Play Store release
- Production monitoring

---

## Current V1 Limitation

This V1 version uses Cloudflare quick tunnel for testing.

That means:

```text
Laravel backend must be running on laptop
Cloudflare tunnel must be running
Cloudflare URL must be updated in Flutter app config
```

When Cloudflare tunnel restarts, the URL changes.

For real production use, the Laravel backend should be deployed to a permanent server/domain.

---

## V2 Roadmap

Planned improvements:

```text
Deploy Laravel backend permanently
Use permanent API URL
Build release APK
Improve battery optimization handling
Improve background tracking reliability
Add push notifications
Add emergency alert dashboard
Add better UI polish
Add Play Store readiness
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
leaflet
```

---

## Suggested Commit Message

```text
Complete SOS app V1 with live tracking and contact import
```

---

## Disclaimer

This app is an emergency assistance tool built for learning and MVP testing.

It should not be treated as a replacement for official emergency services.

Always contact local emergency services directly in real emergencies.
