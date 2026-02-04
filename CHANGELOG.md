# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0-rc.1] - 2026-02-03

### Added
- Forced password change flow on first login
- Scan findings detail view with CVE information
- Full CRUD for admin, integration, and security features
- Multi-server support with dynamic server list and dashboard
- 5-section navigation matching web app layout
- Account icon in top-right of every tab
- Onboarding setup screen with no default server URL
- App icon and logo for iOS and macOS
- Xcode project generation for native macOS/iOS builds
- Nightly release with macOS app and iOS simulator build
- Hide Security, Operations, Admin tabs when not logged in

### Fixed
- Welcome screen scaling, self-signed cert support, and server removal UX
- Return to welcome screen when last server is removed
- Search rewritten to query both repos and artifacts
- Auto-dismiss login sheet on successful authentication
- Login handling when API returns no user object
- Blank repo detail screen
- Blank screen when tapping a package
- iOS models aligned with actual API response format
