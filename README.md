# Artifact Keeper — iOS / macOS

Native iOS and macOS app for Artifact Keeper, built with SwiftUI and targeting iOS 17+ / macOS 14+.

## Tech Stack

- **SwiftUI** with iOS 17+ / macOS 14+ APIs
- **Swift 6** with strict concurrency
- **Alamofire** for networking
- **Swift Dependencies** for dependency injection
- **Kingfisher** for image loading
- **xcodegen** for project generation

## Design

Follows Apple Human Interface Guidelines with:
- Native navigation patterns (NavigationStack, TabView)
- SF Symbols for iconography
- Dynamic Type support
- Dark/Light mode support
- Segmented controls for sub-navigation within sections

## Architecture

### App Launch Flow

```mermaid
flowchart TD
    A[ArtifactKeeperApp] --> B{Server URL\nconfigured?}
    B -->|No| C[WelcomeView\nOnboarding + URL Setup]
    C -->|URL saved| D[MainTabView]
    B -->|Yes| D
    D --> E[5-Section Tab Bar]

    E --> T1[Artifacts]
    E --> T2[Integration]
    E --> T3[Security]
    E --> T4[Operations]
    E --> T5[Administration]
```

### Navigation Structure

```mermaid
flowchart LR
    subgraph TabBar["Tab Bar"]
        direction TB
        A["Artifacts"]
        I["Integration"]
        S["Security"]
        O["Operations"]
        AD["Admin"]
    end

    subgraph ArtifactsSection["Artifacts Section"]
        direction TB
        A1["Repos"] --> A1D["RepositoryDetailView"]
        A1D --> A1A["ArtifactDetailSheet"]
        A2["Packages"] --> A2D["PackageDetailView"]
        A3["Builds"] --> A3D["BuildDetailView"]
        A4["Search"] --> A4D["PackageDetailView"]
    end

    subgraph IntegrationSection["Integration Section"]
        direction TB
        I1["Peers"]
        I2["Replication"]
        I3["Webhooks"]
    end

    subgraph SecuritySection["Security Section"]
        direction TB
        S1["Dashboard"] --> S1D["ScanResultsView"]
        S2["Scans"]
        S3["Policies"]
    end

    subgraph OperationsSection["Operations Section"]
        direction TB
        O1["Analytics"]
        O2["Monitoring"]
        O3["Telemetry"]
    end

    subgraph AdminSection["Admin Section"]
        direction TB
        AD1["Users"]
        AD2["Groups"]
        AD3["SSO"]
        AD4["Settings"]
    end

    A --> ArtifactsSection
    I --> IntegrationSection
    S --> SecuritySection
    O --> OperationsSection
    AD --> AdminSection
```

### View Hierarchy

```mermaid
graph TD
    App[ArtifactKeeperApp] --> CV[ContentView]
    CV --> WV[WelcomeView]
    CV --> MTV[MainTabView]

    MTV --> ASV[ArtifactsSectionView]
    MTV --> ISV[IntegrationSectionView]
    MTV --> SSV[SecuritySectionView]
    MTV --> OSV[OperationsSectionView]
    MTV --> ADSV[AdminSectionView]

    ASV -->|"Segmented Control"| RCV[RepositoriesContentView]
    ASV --> PCV[PackagesContentView]
    ASV --> BCV[BuildsContentView]
    ASV --> SCV[SearchContentView]

    RCV --> RDV[RepositoryDetailView]
    RDV --> ADS[ArtifactDetailSheet]
    PCV --> PDV[PackageDetailView]
    BCV --> BDV[BuildDetailView]
    SCV --> PDV2[PackageDetailView]

    ISV -->|"Segmented Control"| PeV[PeersView]
    ISV --> RepV[ReplicationView]
    ISV --> WhV[WebhooksView]

    SSV -->|"Segmented Control"| SDC[SecurityDashboardContentView]
    SSV --> SSC[SecurityScansContentView]
    SSV --> PolV[PoliciesView]
    SDC --> SRV[ScanResultsView]

    OSV -->|"Segmented Control"| AnV[AnalyticsView]
    OSV --> MonV[MonitoringView]
    OSV --> TelV[TelemetryView]

    ADSV -->|"Segmented Control"| UsV[UsersView]
    ADSV --> GrV[GroupsView]
    ADSV --> SSOV[SSOView]
    ADSV --> SetV[SettingsContentView]
```

### Section Pattern

Each section tab follows the same container pattern:

```mermaid
flowchart TD
    subgraph SectionContainer["Section Container View"]
        direction TB
        NS[NavigationStack] --> Title[".navigationTitle()"]
        NS --> AT[".accountToolbar()"]
        NS --> VStack

        subgraph VStack["VStack"]
            direction TB
            Picker["Picker — Segmented Style\n(sub-page selector)"]
            Divider
            Content["Active Sub-Page Content View"]
        end
    end

    State["@State selectedTab"] -->|"controls"| Picker
    Picker -->|"switches"| Content
```

### Core Layer Architecture

```mermaid
graph TD
    subgraph Views["Feature Views"]
        FV1[RepositoriesContentView]
        FV2[PackagesContentView]
        FV3[SecurityDashboardContentView]
        FV4[AnalyticsView]
        FV5["...other views"]
    end

    subgraph Core["Core Layer"]
        API[APIClient]
        AM[AuthManager]
        ATM[AccountToolbarModifier]
    end

    subgraph Models["Data Models"]
        M1[Repository / Artifact]
        M2[Package / Build]
        M3[Security / ScanResult]
        M4[Peer / Webhook / ReplicationRule]
        M5[AdminUser / AdminGroup / SSOProvider]
        M6[AnalyticsOverview / SystemHealth / TelemetryMetrics]
    end

    Views -->|"apiClient.request()"| API
    Views -->|"@EnvironmentObject"| AM
    Views -->|".accountToolbar()"| ATM
    API -->|"JSON decode"| Models
    ATM -->|"login/logout"| AM
    AM -->|"JWT decode"| API

    API -->|"GET/POST"| Server["Artifact Keeper Server\n/api/v1/*"]
```

### Authentication Flow

```mermaid
sequenceDiagram
    participant U as User
    participant V as LoginView
    participant AM as AuthManager
    participant API as APIClient
    participant S as Server

    U->>V: Enter credentials
    V->>AM: login(username, password)
    AM->>API: POST /api/v1/auth/login
    API->>S: HTTP request
    S-->>API: { access_token, refresh_token }
    API-->>AM: LoginResponse
    AM->>AM: decodeJWT(access_token)
    AM->>AM: Set currentUser, isAuthenticated = true
    AM-->>V: Published state change
    V-->>U: Login sheet auto-dismisses
```

### API Communication

```mermaid
flowchart LR
    subgraph App["iOS / macOS App"]
        AC[APIClient]
    end

    subgraph Endpoints["Backend API Endpoints"]
        direction TB
        E1["GET /api/v1/repositories"]
        E2["GET /api/v1/packages"]
        E3["GET /api/v1/builds"]
        E4["GET /api/v1/security/scores"]
        E5["GET /api/v1/security/scans"]
        E6["GET /api/v1/peers"]
        E7["GET /api/v1/replication/rules"]
        E8["GET /api/v1/webhooks"]
        E9["GET /api/v1/analytics/overview"]
        E10["GET /api/v1/system/health"]
        E11["GET /api/v1/telemetry/metrics"]
        E12["GET /api/v1/admin/users"]
        E13["GET /api/v1/admin/groups"]
        E14["GET /api/v1/admin/sso/providers"]
        E15["POST /api/v1/auth/login"]
    end

    AC <-->|"JSON over HTTPS"| Endpoints
```

### File Structure

```mermaid
graph LR
    subgraph Sources["ArtifactKeeper/Sources"]
        direction TB

        subgraph AppDir["App/"]
            A1["ArtifactKeeperApp.swift"]
            A2["ContentView.swift"]
            A3["MainTabView.swift"]
        end

        subgraph Sections["Sections/"]
            S1["ArtifactsSectionView.swift"]
            S2["IntegrationSectionView.swift"]
            S3["SecuritySectionView.swift"]
            S4["OperationsSectionView.swift"]
            S5["AdminSectionView.swift"]
        end

        subgraph Features["Features/"]
            F1["Repositories/"]
            F2["Packages/"]
            F3["Builds/"]
            F4["Search/"]
            F5["Security/"]
            F6["Integration/"]
            F7["Operations/"]
            F8["Admin/"]
            F9["Dashboard/"]
            F10["Welcome/"]
            F11["Settings/"]
        end

        subgraph CoreDir["Core/"]
            C1["API/APIClient.swift"]
            C2["Auth/AuthManager.swift"]
            C3["Auth/LoginView.swift"]
            C4["Models/*.swift"]
        end

        subgraph UI["UI/"]
            U1["AccountToolbarModifier.swift"]
            U2["Theme/Theme.swift"]
        end
    end
```

## Features

### Artifacts
- Repository browsing with search and filtering
- Artifact details with download links (opens in browser)
- Package list with version history
- Build tracking with status filtering (success/failed/running/pending)
- Full-text search across packages

### Integration
- Peer instance overview with sync status
- Replication rules monitoring
- Webhook configuration viewer

### Security
- Security score dashboard with grade badges (A-F)
- Vulnerability counts by severity (Critical/High/Medium/Low)
- Scan results with expandable details
- Security policy viewer

### Operations
- Analytics dashboard (downloads, uploads, storage, active repos)
- Top packages by download count
- System health monitoring (database, storage status)
- Disk usage with progress indicator
- Telemetry metrics (requests/min, error rate, latency, connections)

### Administration
- User management with role indicators
- Group management with member counts
- SSO provider configuration viewer
- Server URL management and account settings

## Getting Started

1. Install xcodegen: `brew install xcodegen`
2. Generate the Xcode project: `cd artifact-keeper-ios && xcodegen generate`
3. Open `ArtifactKeeper.xcodeproj` in Xcode 16+
4. Build and run for iOS Simulator, device, or macOS (universal app)

On first launch, enter your Artifact Keeper server URL (e.g. `http://localhost:30080` for local development).
