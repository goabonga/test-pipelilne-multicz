# Changelog

All notable changes to this component are documented here.

## [0.1.0] - 2026-08-11

### Features

- **app**: scaffold the React Native (bare) mobile app (`56ed132`)
- **app**: publish signed store builds when secrets are configured (`31ae54b`)
- cut a synchronized release baseline across all components (`eb7f6d3`)
- **app**: publish package metadata (`e6db771`)

### Fixes

- **deps**: bump react from 19.2.3 to 19.2.7 in /packages/app (`1692fa6`)
- **app**: unblock app-sbom and app-mobsfscan (`681450e`)
- **app**: pin the Gradle wrapper to 9.3.1 for React Native 0.86 (`b1239dc`)
- **app**: make the Maestro e2e flow pass on Android and iOS (`194ee5d`)
- **app**: submit the e2e login via the keyboard return key (`0f7b90d`)
- **app**: pin Babel 7 and Jest 29 for React Native 0.86 (`3186e94`)
- **deps**: clear the high-severity advisories in the app dependency tree (`00ffff5`)
- **deps**: raise the app overrides past two new high-severity advisories (`7d4a615`)

### Dependencies

- Track `lib` `0.1.0`
