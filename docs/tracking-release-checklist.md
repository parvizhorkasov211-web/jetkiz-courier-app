# Courier app GPS release checklist

## Build identity

Before generating a Play release, confirm `applicationId` in `android/app/build.gradle.kts` exactly matches the existing Google Play application. Do not change it merely to remove an `example` namespace after a Play listing exists.

Release builds require `android/key.properties` and a private keystore. These files are intentionally gitignored.

## API

Default production API: `https://api.jetkiz.asia`.

Override only for staging/local builds:

```text
--dart-define=JETKIZ_API_BASE_URL=https://...
```

## Android location

The manifest contains:

- internet access;
- coarse/fine location;
- background location;
- foreground-service permissions including location foreground service.

The tracking service publishes GPS only while the authenticated courier is online or still has an active delivery. Android tracking uses a foreground notification so an active delivery can continue outside the foreground UI.

## Device acceptance test

Test on at least one current Android version and one older supported Android version:

1. Login with a real courier account.
2. Deny location permission: app must not crash and backend must not receive fake coordinates.
3. Grant location permission.
4. Switch online and verify a fresh map point appears after a real GPS fix.
5. Move at least 100 metres and confirm the point changes.
6. Lock the phone for several minutes during an active order; GPS must continue and the foreground notification must remain visible.
7. Disable network temporarily, then restore it; tracking must recover without re-login.
8. Disable location services; admin must eventually receive stale-GPS diagnostics rather than a permanently green courier.
9. Switch offline with no active order; tracking must stop.
10. Switch offline while an active order exists; tracking must continue until the order is no longer active.
11. Reset/revoke the courier session and verify publishing no longer authenticates.

## Store policy

Background location is sensitive. The Play Console declaration, privacy policy and in-app explanation must accurately describe why courier location is required during active work/delivery. Do not request background access for unrelated client roles.
