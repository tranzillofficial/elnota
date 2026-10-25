# Preview release distribution

All source and binary releases belong to tranzillofficial/elnotaapp. The legacy repository and domain are unchanged.

## Public downloads
Android and Windows cards read published elnota_app_releases rows with a public client key and 60-second revalidation. iOS stays Coming soon until an administrator supplies an App Store URL. Android can switch from APK to Google Play without a frontend release. Windows is x64; x86 users use the browser.

## Administrator workflow
The existing server-authorized admin dashboard includes release upload/version/notes and store URLs. The new bucket elnota-app-releases is public and accepts inserts only by elnota_is_admin(). Existing files cannot be overwritten or deleted through these policies. No application size limit. Bucket-specific cap removed; project/provider quotas still apply. Large binaries can use GitHub release asset URLs. Supporting files can be uploaded as public ZIP archives. Never upload signing keys, passwords, environment files, or customer backups.

Publishing goes through elnota_publish_release: verifies server admin identity, locks the platform, archives the previous published metadata, and publishes a new row atomically. A failure rolls back the previous publication state. Customer/account/ledger tables are not modified. The web build enables server-authorized admin actions; cloud ledger sync remains disabled.

## Android signing
Release builds require ignored android/key.properties and a private keystore. No debug signing fallback. This machine holds the preview signing key outside the repository in the current user .elnota-signing directory. Preserve that directory securely for compatible preview updates. This key is not evidence of compatibility with any legacy installed application. Never uninstall an existing customer installation to bypass a signing mismatch.

## Windows
Build with Flutter release, public Auth defines only, then compile distribution/windows/elnota.iss. Inno Setup 6.4.3 is used under its included permissive license. Keep the AppId stable. Installer compilation has been checked; physical device install/update testing remains necessary. No Windows code-signing certificate is configured.

## QR authentication
The additive device-login function and elnota_device_links table are deployed. CORS defaults to the independent preview web origin. Create/poll use a random browser proof; inspect/approve require a confirmed authenticated activated account. Codes expire in three minutes and are consumed atomically. No ledger synchronization is enabled by pairing. Full phone-camera pairing must be verified on a physical Android device.

## Android 1.0.2 compatibility preview
The new Android preview uses shop.elnota.preview for isolated test installs. The new preview does not replace or migrate com.example.elnota data. Android and iOS display names are ElNota. Native libraries are compressed with useLegacyPackaging; this reduces download size, but libraries are extracted during installation. Per-ABI APKs remove other architectures entirely. Keep minSdk unchanged; never claim older Android support without testing.
Release metadata has an optional assets JSON object (arm32/arm64). Landing renders only allowlisted asset URLs. No customer, account, ledger or backup schema was changed.
