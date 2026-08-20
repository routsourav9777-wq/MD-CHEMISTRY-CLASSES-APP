# Chemistry Coaching Centre App

Premium animated Flutter + Firebase starter/source.

## Backend
- Firebase Authentication
- Cloud Firestore
- Firebase Storage
- Firebase Cloud Messaging
- Firestore + Storage security rules

## Important
Firebase client configuration is intentionally NOT included.
After creating the Flutter project, run:

flutterfire configure

This generates `lib/firebase_options.dart`.

Then:

flutter pub get
flutter run

## Admin account
Create the admin user in Firebase Authentication, then create:
`users/{ADMIN_UID}`

Example:
{
  "name": "Chemistry Admin",
  "email": "admin@example.com",
  "role": "admin",
  "status": "approved",
  "createdAt": <timestamp>
}

## Student registration
The app creates a student profile with:
role = student
status = pending

The admin can approve the user by changing status to `approved`.

## Screenshot protection
The Android MainActivity example below shows the native FLAG_SECURE implementation.
If you create a fresh Flutter project with `flutter create`, copy the Kotlin snippet from:
`android_FLAG_SECURE_SNIPPET.kt`
into your MainActivity.

## Suggested workflow
1. Create a fresh Flutter project.
2. Replace its `lib/` with this package's `lib/`.
3. Copy pubspec.yaml.
4. Run `flutterfire configure`.
5. Deploy Firestore and Storage rules.
6. Create an admin Firebase Auth account and admin Firestore document.
7. Run the app.

The UI is designed to be extended with the full Admin Notes/Notices CRUD and Student PDF modules.
