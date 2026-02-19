# iOS/macOS Test Plan

## Overview

The artifact-keeper iOS/macOS app uses SwiftUI with Swift 6 strict concurrency. Testing infrastructure is in early stages.

## Test Inventory

| Test Type | Framework | Count | CI Job | Status |
|-----------|-----------|-------|--------|--------|
| Build | swift build | Full app | `build` | Active |
| Unit | XCTest | 1 stub | - | Stub only |
| UI | XCUITest | 0 | - | Missing |
| Snapshot | (none) | 0 | - | Missing |

## How to Run

### Build
```bash
swift build
```

### Unit Tests
```bash
swift test
```

### Generate Xcode Project (for UI tests)
```bash
xcodegen generate
open ArtifactKeeper.xcodeproj
# Run tests via Xcode: Cmd+U
```

## CI Pipeline

```
PR opened/pushed
  -> build (swift build on macOS 15)

Merge to main
  -> build + nightly release (macOS + iOS simulator builds)

Tag v*
  -> archive + App Store upload
```

## Gaps and Roadmap

| Gap | Recommendation | Priority |
|-----|---------------|----------|
| No real unit tests | Add XCTest cases for APIClient, AuthManager, data models | P1 |
| No UI tests | Add XCUITest for login, browse, search flows | P2 |
| No snapshot tests | Add swift-snapshot-testing for SwiftUI views | P3 |
| No test CI job | Add `swift test` step to CI workflow | P1 |
