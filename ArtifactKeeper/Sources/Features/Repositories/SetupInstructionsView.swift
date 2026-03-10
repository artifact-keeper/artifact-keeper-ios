import SwiftUI

// MARK: - Setup Step Model

struct SetupStep: Identifiable {
    let id = UUID()
    let title: String
    let description: String?
    let code: String
}

// MARK: - Setup Instructions View

struct SetupInstructionsView: View {
    let repo: Repository
    @State private var serverURL: String = ""
    @State private var serverHost: String = ""

    private let apiClient = APIClient.shared

    var body: some View {
        let steps = setupSteps(for: repo)

        if steps.isEmpty {
            ContentUnavailableView(
                "No Setup Instructions",
                systemImage: "doc.text",
                description: Text("Setup instructions are not available for this format yet.")
            )
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Configure your tools to work with the \(repo.name) repository.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        SetupStepCard(index: index + 1, step: step)
                    }
                }
                .padding(.vertical)
            }
            .task {
                let url = await apiClient.getBaseURL()
                serverURL = url
                if let parsed = URL(string: url) {
                    serverHost = parsed.host ?? "artifacts.example.com"
                    if let port = parsed.port, port != 443, port != 80 {
                        serverHost += ":\(port)"
                    }
                } else {
                    serverHost = "artifacts.example.com"
                }
            }
        }
    }

    // MARK: - Format-Specific Steps

    private func setupSteps(for repo: Repository) -> [SetupStep] {
        SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
    }
}

// MARK: - Extracted Helper (testable)

enum SetupInstructionsHelper {

    /// Derive the host string (with optional port) from a URL.
    static func deriveHost(from url: String) -> String {
        if let parsed = URL(string: url) {
            var host = parsed.host ?? "artifacts.example.com"
            if let port = parsed.port, port != 443, port != 80 {
                host += ":\(port)"
            }
            return host
        }
        return "artifacts.example.com"
    }

    static func steps(for repo: Repository, serverURL: String, serverHost: String) -> [SetupStep] {
        let key = repo.key
        let url = serverURL.isEmpty ? "https://artifacts.example.com" : serverURL
        let host = serverHost.isEmpty ? "artifacts.example.com" : serverHost

        switch repo.format {
        case "npm", "yarn", "pnpm":
            return [
                SetupStep(
                    title: "Configure registry",
                    description: "Add to your .npmrc file or run:",
                    code: """
                    npm config set @\(key):registry \(url)/npm/\(key)/
                    npm config set //\(host)/npm/\(key)/:_authToken YOUR_TOKEN
                    """
                ),
                SetupStep(
                    title: "Install a package",
                    description: nil,
                    code: "npm install @\(key)/<package-name>"
                ),
                SetupStep(
                    title: "Publish a package",
                    description: nil,
                    code: "npm publish --registry \(url)/npm/\(key)/"
                ),
            ]

        case "pypi", "poetry", "conda":
            return [
                SetupStep(
                    title: "Configure pip",
                    description: "Add to ~/.pip/pip.conf or ~/.config/pip/pip.conf:",
                    code: """
                    [global]
                    index-url = \(url)/pypi/\(key)/simple/
                    trusted-host = \(host)
                    """
                ),
                SetupStep(
                    title: "Install a package",
                    description: nil,
                    code: "pip install --index-url \(url)/pypi/\(key)/simple/ <package-name>"
                ),
                SetupStep(
                    title: "Upload with twine",
                    description: nil,
                    code: "twine upload --repository-url \(url)/pypi/\(key)/ dist/*"
                ),
            ]

        case "maven", "gradle", "sbt":
            return [
                SetupStep(
                    title: "Configure settings.xml",
                    description: "Add to ~/.m2/settings.xml:",
                    code: """
                    <settings>
                      <servers>
                        <server>
                          <id>\(key)</id>
                          <username>YOUR_USERNAME</username>
                          <password>YOUR_TOKEN</password>
                        </server>
                      </servers>
                    </settings>
                    """
                ),
                SetupStep(
                    title: "Add repository to pom.xml",
                    description: nil,
                    code: """
                    <repositories>
                      <repository>
                        <id>\(key)</id>
                        <url>\(url)/maven/\(key)/</url>
                      </repository>
                    </repositories>
                    """
                ),
                SetupStep(
                    title: "Deploy artifacts",
                    description: nil,
                    code: "mvn deploy"
                ),
            ]

        case "docker", "podman", "buildx", "oras":
            return [
                SetupStep(
                    title: "Login to registry",
                    description: nil,
                    code: "docker login \(host)"
                ),
                SetupStep(
                    title: "Tag an image",
                    description: nil,
                    code: "docker tag my-image:latest \(host)/\(key)/my-image:latest"
                ),
                SetupStep(
                    title: "Push an image",
                    description: nil,
                    code: "docker push \(host)/\(key)/my-image:latest"
                ),
                SetupStep(
                    title: "Pull an image",
                    description: nil,
                    code: "docker pull \(host)/\(key)/my-image:latest"
                ),
            ]

        case "incus", "lxc":
            return [
                SetupStep(
                    title: "Add as SimpleStreams remote",
                    description: nil,
                    code: """
                    incus remote add \(key) \(url)/incus/\(key) \\
                      --protocol simplestreams --public
                    """
                ),
                SetupStep(
                    title: "Upload an image",
                    description: nil,
                    code: """
                    curl -X PUT -u admin:password \\
                      -H "Content-Type: application/x-xz" \\
                      --data-binary @image.tar.xz \\
                      \(url)/incus/\(key)/images/ubuntu-noble/20240215/incus.tar.xz
                    """
                ),
                SetupStep(
                    title: "List images",
                    description: nil,
                    code: "incus image list \(key):"
                ),
                SetupStep(
                    title: "Launch a container",
                    description: nil,
                    code: "incus launch \(key):ubuntu-noble my-container"
                ),
            ]

        case "cargo":
            return [
                SetupStep(
                    title: "Configure Cargo",
                    description: "Add to ~/.cargo/config.toml:",
                    code: """
                    [registries.\(key)]
                    index = "\(url)/cargo/\(key)/index"
                    token = "YOUR_TOKEN"
                    """
                ),
                SetupStep(
                    title: "Publish a crate",
                    description: nil,
                    code: "cargo publish --registry \(key)"
                ),
                SetupStep(
                    title: "Add a dependency",
                    description: "In Cargo.toml:",
                    code: """
                    [dependencies]
                    my-crate = { version = "0.1", registry = "\(key)" }
                    """
                ),
            ]

        case "helm", "helm_oci":
            return [
                SetupStep(
                    title: "Add Helm repository",
                    description: nil,
                    code: """
                    helm repo add \(key) \(url)/helm/\(key)/
                    helm repo update
                    """
                ),
                SetupStep(
                    title: "Push a chart",
                    description: nil,
                    code: "helm push my-chart-0.1.0.tgz oci://\(host)/\(key)/"
                ),
                SetupStep(
                    title: "Install a chart",
                    description: nil,
                    code: "helm install my-release \(key)/my-chart"
                ),
            ]

        case "nuget":
            return [
                SetupStep(
                    title: "Add NuGet source",
                    description: nil,
                    code: """
                    dotnet nuget add source \(url)/nuget/\(key)/v3/index.json \\
                      --name \(key) --username YOUR_USERNAME --password YOUR_TOKEN
                    """
                ),
                SetupStep(
                    title: "Push a package",
                    description: nil,
                    code: "dotnet nuget push MyPackage.1.0.0.nupkg --source \(key) --api-key YOUR_TOKEN"
                ),
                SetupStep(
                    title: "Install a package",
                    description: nil,
                    code: "dotnet add package MyPackage --source \(key)"
                ),
            ]

        case "go":
            return [
                SetupStep(
                    title: "Configure Go proxy",
                    description: nil,
                    code: """
                    export GOPROXY=\(url)/go/\(key),direct
                    export GONOSUMCHECK=*
                    """
                ),
                SetupStep(
                    title: "Add a dependency",
                    description: nil,
                    code: "go get example.com/my-module@latest"
                ),
            ]

        case "rubygems":
            return [
                SetupStep(
                    title: "Configure Bundler",
                    description: "In your Gemfile:",
                    code: "source \"\(url)/gems/\(key)/\""
                ),
                SetupStep(
                    title: "Push a gem",
                    description: nil,
                    code: "gem push my-gem-0.1.0.gem --host \(url)/gems/\(key)/"
                ),
            ]

        case "debian":
            return [
                SetupStep(
                    title: "Add APT repository",
                    description: "Add to /etc/apt/sources.list.d/artifact-keeper.list:",
                    code: "deb \(url)/debian/\(key)/ stable main"
                ),
                SetupStep(
                    title: "Update and install",
                    description: nil,
                    code: """
                    sudo apt update
                    sudo apt install <package-name>
                    """
                ),
            ]

        case "rpm":
            return [
                SetupStep(
                    title: "Add YUM/DNF repository",
                    description: "Create /etc/yum.repos.d/artifact-keeper.repo:",
                    code: """
                    [\(key)]
                    name=Artifact Keeper - \(repo.name)
                    baseurl=\(url)/rpm/\(key)/
                    enabled=1
                    gpgcheck=0
                    """
                ),
                SetupStep(
                    title: "Install a package",
                    description: nil,
                    code: "sudo dnf install <package-name>"
                ),
            ]

        case "terraform", "opentofu":
            return [
                SetupStep(
                    title: "Configure provider mirror",
                    description: "In ~/.terraformrc:",
                    code: """
                    provider_installation {
                      network_mirror {
                        url = "\(url)/terraform/\(key)/"
                      }
                    }
                    """
                ),
            ]

        case "composer":
            return [
                SetupStep(
                    title: "Add Composer repository",
                    description: nil,
                    code: "composer config repositories.\(key) composer \(url)/composer/\(key)/"
                ),
                SetupStep(
                    title: "Require a package",
                    description: nil,
                    code: "composer require vendor/package"
                ),
            ]

        case "alpine":
            return [
                SetupStep(
                    title: "Add APK repository",
                    description: "Add to /etc/apk/repositories:",
                    code: "\(url)/alpine/\(key)/"
                ),
                SetupStep(
                    title: "Install a package",
                    description: nil,
                    code: "apk add <package-name>"
                ),
            ]

        case "protobuf":
            return [
                SetupStep(
                    title: "Configure buf.yaml",
                    description: "Set the registry in your module's buf.yaml:",
                    code: """
                    # buf.yaml
                    version: v2
                    modules:
                      - path: proto
                        name: \(host)/proto/\(key)/myorg/mymodule
                    """
                ),
                SetupStep(
                    title: "Authenticate with buf CLI",
                    description: nil,
                    code: "buf registry login \(host) --username YOUR_USERNAME --token-stdin <<< \"YOUR_TOKEN\""
                ),
                SetupStep(
                    title: "Push a module",
                    description: nil,
                    code: "buf push --registry \(url)/proto/\(key)"
                ),
            ]

        default:
            // Generic format
            return [
                SetupStep(
                    title: "Upload an artifact",
                    description: nil,
                    code: """
                    curl -X PUT -H "Authorization: Bearer YOUR_TOKEN" \\
                      -T ./my-file.tar.gz \\
                      \(url)/api/v1/repositories/\(key)/artifacts/my-file.tar.gz
                    """
                ),
                SetupStep(
                    title: "Download an artifact",
                    description: nil,
                    code: "curl -O \(url)/api/v1/repositories/\(key)/artifacts/my-file.tar.gz"
                ),
            ]
        }
    }
}

// MARK: - Setup Step Card

private struct SetupStepCard: View {
    let index: Int
    let step: SetupStep

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("\(index)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Color.accentColor, in: Circle())

                Text(step.title)
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal)

            if let desc = step.description {
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 50)
                    .padding(.trailing)
            }

            CodeBlockView(code: step.code)
                .padding(.leading, 50)
                .padding(.trailing)
        }
    }
}

// MARK: - Code Block with Copy Button

private struct CodeBlockView: View {
    let code: String
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Text(code)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    copyToClipboard()
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(copied ? .green : .secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Copy to clipboard")
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }

    private func copyToClipboard() {
        #if os(iOS)
        UIPasteboard.general.string = code
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        #endif

        withAnimation {
            copied = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                copied = false
            }
        }
    }
}
