<!-- Types: Added, Changed, Deprecated, Removed, Fixed, Security -->
# 1.10.1 Monthly dependency maintenance
- [changed] Updated the Swift Package Manager dependency floors to Firebase Apple SDK 12.19.1 and SwiftSoup 2.13.9, the current stable releases when this version was finalized.
- [changed] Updated the CocoaPods dependencies to FirebaseMessaging 12.19.x and SwiftSoup 2.11.3. SwiftSoup 2.11.3 is the newest version available through CocoaPods; newer SwiftSoup releases are available through Swift Package Manager.
- [fixed] Incorporated Firebase Messaging 12.19 fixes for registration-token callbacks at app launch, cached-token handling across locale changes, and malformed incoming payloads.
- [security] Updated the Fastlane release toolchain to remove vulnerable Excon versions below 1.5.0 and Faraday versions through 1.10.5.
- [changed] This maintenance release contains no SDK implementation or public API changes relative to 1.10.0.
- [deprecated] CocoaPods installation remains deprecated. Use Swift Package Manager for future Ortto iOS SDK releases.

# 1.9.1 Firebase 12 and CocoaPods maintenance release
- [security] Updated Firebase Messaging support to Firebase Apple SDK 12.x, the current Firebase-maintained major version for this release.
- [changed] Swift Package Manager now supports Firebase 12.x via `.upToNextMajor(from: "12.0.0")`, allowing `>= 12.0.0` and `< 13.0.0`.
- [changed] CocoaPods now supports FirebaseMessaging 12.x via `~> 12.0` for this final CocoaPods maintenance release.
- [deprecated] CocoaPods installation is deprecated. Use Swift Package Manager for future Ortto iOS SDK releases.
- [changed] Firebase 11.x and older are no longer supported by this release because Google only maintains the latest Firebase major version: https://firebase.google.com/policies/changes-to-firebase/versioning-and-maintenance
- [changed] Firebase 13.x is not included in this compatibility range and will require a future Ortto SDK compatibility update.
- [changed] Firebase 12 requires iOS 15.0 and Xcode 26.2 or later.

# 1.3.0 General Package Update
- [changed] We have updated the core Ortto SDK package name to OrttoSDKCore from OrttoPushSDKCore
- [added] Added swift linting and tests setup
- [changed] Upgraded firebase messaging to v10+

# 1.2.2 Improve firebase package support
- [fixed] Sets firebase-messaging version to 8.0.0
- [fixed] Fixes the serviceextension image expiry

# 1.2.1 Adds package modules
- [added] Adds APNS and Firebase modules

# 1.2.0 Initial Release
- First public release of the Ortto Push SDK
