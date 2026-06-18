# Photo Sync Flutter Android App

Flutter Android client for the existing `photo-folder` website API.

Features:
- Google sign-in on Android.
- Stores API/JWT configuration in secure storage.
- Creates an S3 folder through `POST /api/s3/mkdir`.
- Lets the user pick a start and end date.
- Finds photos in the Android `DCIM/Camera` / `Camera` album in that date range.
- Requests a presigned URL from `POST /api/sync/presign` and uploads each photo with HTTP PUT.

## Backend API expected

- `POST /api/auth/login` with JSON `{ email, provider: "google", idToken? }` returns `accessToken`, `refreshToken`.
- `POST /api/auth/refresh` with JSON `{ refreshToken }` returns fresh tokens.
- `GET /api/s3/folders` returns `{ folders: [...] }`.
- `POST /api/s3/mkdir` with JSON `{ name }` creates the folder.
- `POST /api/sync/presign` with JSON `{ key, content_type }` returns `{ presignedUrl }`.

## Configure and run

1. Install Flutter.
2. In Firebase/Google Cloud configure an Android OAuth client for your package/signing key.
3. Optional but recommended: configure a Web OAuth client and pass its client ID in the app settings so `idToken` is available.
4. From this directory run:

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=https://your-site.example.com
```

You can also set/change the API URL and Google Web Client ID in the app settings screen.
