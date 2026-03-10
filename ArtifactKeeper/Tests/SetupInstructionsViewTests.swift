import Testing
import Foundation
@testable import ArtifactKeeper

// MARK: - Test Helpers

/// Convenience factory for building Repository values in tests.
private func makeRepo(
    key: String = "my-repo",
    name: String = "My Repo",
    format: String
) -> Repository {
    Repository(
        id: UUID().uuidString,
        key: key,
        name: name,
        format: format,
        repoType: "local",
        isPublic: false,
        description: nil,
        storageUsedBytes: 0,
        quotaBytes: nil,
        createdAt: "2025-01-01T00:00:00Z",
        updatedAt: "2025-01-01T00:00:00Z"
    )
}

// MARK: - SetupStep Model Tests

@Suite("SetupStep Model Tests")
struct SetupStepModelTests {

    @Test func stepHasUniqueId() {
        let a = SetupStep(title: "A", description: nil, code: "echo a")
        let b = SetupStep(title: "B", description: nil, code: "echo b")
        #expect(a.id != b.id)
    }

    @Test func stepStoresAllFields() {
        let step = SetupStep(title: "Configure", description: "Add to config", code: "npm config set ...")
        #expect(step.title == "Configure")
        #expect(step.description == "Add to config")
        #expect(step.code == "npm config set ...")
    }

    @Test func stepDescriptionCanBeNil() {
        let step = SetupStep(title: "Install", description: nil, code: "npm install foo")
        #expect(step.description == nil)
    }
}

// MARK: - SetupInstructionsHelper.deriveHost Tests

@Suite("SetupInstructionsHelper.deriveHost Tests")
struct DeriveHostTests {

    @Test func simpleHTTPS() {
        let host = SetupInstructionsHelper.deriveHost(from: "https://registry.example.com")
        #expect(host == "registry.example.com")
    }

    @Test func standardPortsOmitted() {
        let host443 = SetupInstructionsHelper.deriveHost(from: "https://registry.example.com:443")
        #expect(host443 == "registry.example.com")

        let host80 = SetupInstructionsHelper.deriveHost(from: "http://registry.example.com:80")
        #expect(host80 == "registry.example.com")
    }

    @Test func customPortIncluded() {
        let host = SetupInstructionsHelper.deriveHost(from: "https://registry.example.com:8080")
        #expect(host == "registry.example.com:8080")
    }

    @Test func invalidURLReturnsFallback() {
        let host = SetupInstructionsHelper.deriveHost(from: "")
        #expect(host == "artifacts.example.com")
    }

    @Test func localhostWithPort() {
        let host = SetupInstructionsHelper.deriveHost(from: "http://localhost:8080")
        #expect(host == "localhost:8080")
    }
}

// MARK: - NPM/Yarn/PNPM Format Steps

@Suite("Setup Steps: NPM Format")
struct NPMSetupStepsTests {

    private let serverURL = "https://registry.example.com"
    private let serverHost = "registry.example.com"

    @Test func npmGenerates3Steps() {
        let repo = makeRepo(key: "npm-local", format: "npm")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps.count == 3)
    }

    @Test func npmConfigureRegistryStep() {
        let repo = makeRepo(key: "npm-local", format: "npm")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        let configStep = steps[0]
        #expect(configStep.title == "Configure registry")
        #expect(configStep.code.contains("npm config set"))
        #expect(configStep.code.contains("npm-local"))
        #expect(configStep.code.contains(serverURL))
        #expect(configStep.code.contains("_authToken"))
    }

    @Test func npmInstallStep() {
        let repo = makeRepo(key: "npm-local", format: "npm")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps[1].code.contains("npm install"))
    }

    @Test func npmPublishStep() {
        let repo = makeRepo(key: "npm-local", format: "npm")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps[2].code.contains("npm publish"))
        #expect(steps[2].code.contains("--registry"))
    }

    @Test func yarnUsesNpmSteps() {
        let repo = makeRepo(key: "yarn-local", format: "yarn")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps.count == 3)
        #expect(steps[0].code.contains("yarn-local"))
    }

    @Test func pnpmUsesNpmSteps() {
        let repo = makeRepo(key: "pnpm-local", format: "pnpm")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps.count == 3)
    }
}

// MARK: - PyPI Format Steps

@Suite("Setup Steps: PyPI Format")
struct PyPISetupStepsTests {

    private let serverURL = "https://registry.example.com"
    private let serverHost = "registry.example.com"

    @Test func pypiGenerates3Steps() {
        let repo = makeRepo(key: "pypi-local", format: "pypi")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps.count == 3)
    }

    @Test func pypiConfigureStep() {
        let repo = makeRepo(key: "pypi-local", format: "pypi")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps[0].code.contains("index-url"))
        #expect(steps[0].code.contains("/pypi/pypi-local/simple/"))
        #expect(steps[0].code.contains("trusted-host"))
    }

    @Test func pypiInstallStep() {
        let repo = makeRepo(key: "pypi-local", format: "pypi")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps[1].code.contains("pip install"))
        #expect(steps[1].code.contains("--index-url"))
    }

    @Test func pypiUploadStep() {
        let repo = makeRepo(key: "pypi-local", format: "pypi")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps[2].code.contains("twine upload"))
        #expect(steps[2].code.contains("--repository-url"))
    }

    @Test func poetryUsePyPISteps() {
        let repo = makeRepo(key: "poetry-local", format: "poetry")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps.count == 3)
    }

    @Test func condaUsesPyPISteps() {
        let repo = makeRepo(key: "conda-local", format: "conda")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps.count == 3)
    }
}

// MARK: - Maven Format Steps

@Suite("Setup Steps: Maven Format")
struct MavenSetupStepsTests {

    private let serverURL = "https://registry.example.com"
    private let serverHost = "registry.example.com"

    @Test func mavenGenerates3Steps() {
        let repo = makeRepo(key: "maven-local", format: "maven")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps.count == 3)
    }

    @Test func mavenSettingsXmlStep() {
        let repo = makeRepo(key: "maven-local", format: "maven")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps[0].title == "Configure settings.xml")
        #expect(steps[0].code.contains("<server>"))
        #expect(steps[0].code.contains("<id>maven-local</id>"))
    }

    @Test func mavenPomXmlStep() {
        let repo = makeRepo(key: "maven-local", format: "maven")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps[1].code.contains("<repository>"))
        #expect(steps[1].code.contains("/maven/maven-local/"))
    }

    @Test func mavenDeployStep() {
        let repo = makeRepo(key: "maven-local", format: "maven")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps[2].code.contains("mvn deploy"))
    }

    @Test func gradleUseMavenSteps() {
        let repo = makeRepo(key: "gradle-repo", format: "gradle")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps.count == 3)
    }

    @Test func sbtUseMavenSteps() {
        let repo = makeRepo(key: "sbt-repo", format: "sbt")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps.count == 3)
    }
}

// MARK: - Docker Format Steps

@Suite("Setup Steps: Docker Format")
struct DockerSetupStepsTests {

    private let serverURL = "https://registry.example.com"
    private let serverHost = "registry.example.com"

    @Test func dockerGenerates4Steps() {
        let repo = makeRepo(key: "docker-local", format: "docker")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps.count == 4)
    }

    @Test func dockerLoginStep() {
        let repo = makeRepo(key: "docker-local", format: "docker")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps[0].code.contains("docker login"))
        #expect(steps[0].code.contains(serverHost))
    }

    @Test func dockerTagStep() {
        let repo = makeRepo(key: "docker-local", format: "docker")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps[1].code.contains("docker tag"))
        #expect(steps[1].code.contains("docker-local"))
    }

    @Test func dockerPushStep() {
        let repo = makeRepo(key: "docker-local", format: "docker")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps[2].code.contains("docker push"))
    }

    @Test func dockerPullStep() {
        let repo = makeRepo(key: "docker-local", format: "docker")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps[3].code.contains("docker pull"))
    }

    @Test func podmanUsesDockerSteps() {
        let repo = makeRepo(key: "oci-local", format: "podman")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps.count == 4)
    }

    @Test func orasUsesDockerSteps() {
        let repo = makeRepo(key: "oci-local", format: "oras")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps.count == 4)
    }
}

// MARK: - Cargo Format Steps

@Suite("Setup Steps: Cargo Format")
struct CargoSetupStepsTests {

    private let serverURL = "https://registry.example.com"
    private let serverHost = "registry.example.com"

    @Test func cargoGenerates3Steps() {
        let repo = makeRepo(key: "cargo-local", format: "cargo")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps.count == 3)
    }

    @Test func cargoConfigStep() {
        let repo = makeRepo(key: "cargo-local", format: "cargo")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps[0].code.contains("[registries.cargo-local]"))
        #expect(steps[0].code.contains("/cargo/cargo-local/index"))
    }

    @Test func cargoPublishStep() {
        let repo = makeRepo(key: "cargo-local", format: "cargo")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps[1].code.contains("cargo publish"))
        #expect(steps[1].code.contains("--registry cargo-local"))
    }

    @Test func cargoDependencyStep() {
        let repo = makeRepo(key: "cargo-local", format: "cargo")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps[2].code.contains("[dependencies]"))
        #expect(steps[2].code.contains("registry = \"cargo-local\""))
    }
}

// MARK: - Helm Format Steps

@Suite("Setup Steps: Helm Format")
struct HelmSetupStepsTests {

    private let serverURL = "https://registry.example.com"
    private let serverHost = "registry.example.com"

    @Test func helmGenerates3Steps() {
        let repo = makeRepo(key: "helm-local", format: "helm")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps.count == 3)
    }

    @Test func helmRepoAddStep() {
        let repo = makeRepo(key: "helm-local", format: "helm")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps[0].code.contains("helm repo add"))
        #expect(steps[0].code.contains("helm repo update"))
    }

    @Test func helmOciUsesHelmSteps() {
        let repo = makeRepo(key: "helm-oci", format: "helm_oci")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps.count == 3)
    }
}

// MARK: - NuGet Format Steps

@Suite("Setup Steps: NuGet Format")
struct NuGetSetupStepsTests {

    private let serverURL = "https://registry.example.com"
    private let serverHost = "registry.example.com"

    @Test func nugetGenerates3Steps() {
        let repo = makeRepo(key: "nuget-local", format: "nuget")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps.count == 3)
    }

    @Test func nugetAddSourceStep() {
        let repo = makeRepo(key: "nuget-local", format: "nuget")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps[0].code.contains("dotnet nuget add source"))
        #expect(steps[0].code.contains("/nuget/nuget-local/v3/index.json"))
    }

    @Test func nugetPushStep() {
        let repo = makeRepo(key: "nuget-local", format: "nuget")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps[1].code.contains("dotnet nuget push"))
    }
}

// MARK: - Go Format Steps

@Suite("Setup Steps: Go Format")
struct GoSetupStepsTests {

    private let serverURL = "https://registry.example.com"
    private let serverHost = "registry.example.com"

    @Test func goGenerates2Steps() {
        let repo = makeRepo(key: "go-local", format: "go")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps.count == 2)
    }

    @Test func goProxyStep() {
        let repo = makeRepo(key: "go-local", format: "go")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps[0].code.contains("GOPROXY="))
        #expect(steps[0].code.contains("/go/go-local"))
        #expect(steps[0].code.contains("GONOSUMCHECK"))
    }
}

// MARK: - Debian Format Steps

@Suite("Setup Steps: Debian Format")
struct DebianSetupStepsTests {

    private let serverURL = "https://registry.example.com"
    private let serverHost = "registry.example.com"

    @Test func debianGenerates2Steps() {
        let repo = makeRepo(key: "deb-local", format: "debian")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps.count == 2)
    }

    @Test func debianAptSourceStep() {
        let repo = makeRepo(key: "deb-local", format: "debian")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps[0].code.contains("deb "))
        #expect(steps[0].code.contains("/debian/deb-local/"))
    }
}

// MARK: - RPM Format Steps

@Suite("Setup Steps: RPM Format")
struct RPMSetupStepsTests {

    private let serverURL = "https://registry.example.com"
    private let serverHost = "registry.example.com"

    @Test func rpmGenerates2Steps() {
        let repo = makeRepo(key: "rpm-local", format: "rpm")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps.count == 2)
    }

    @Test func rpmRepoConfigStep() {
        let repo = makeRepo(key: "rpm-local", format: "rpm")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps[0].code.contains("[rpm-local]"))
        #expect(steps[0].code.contains("baseurl="))
        #expect(steps[0].code.contains("/rpm/rpm-local/"))
    }
}

// MARK: - Terraform Format Steps

@Suite("Setup Steps: Terraform Format")
struct TerraformSetupStepsTests {

    private let serverURL = "https://registry.example.com"
    private let serverHost = "registry.example.com"

    @Test func terraformGenerates1Step() {
        let repo = makeRepo(key: "tf-local", format: "terraform")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps.count == 1)
    }

    @Test func terraformMirrorStep() {
        let repo = makeRepo(key: "tf-local", format: "terraform")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps[0].code.contains("provider_installation"))
        #expect(steps[0].code.contains("network_mirror"))
        #expect(steps[0].code.contains("/terraform/tf-local/"))
    }

    @Test func opentofuUsesTerraformSteps() {
        let repo = makeRepo(key: "tofu-local", format: "opentofu")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps.count == 1)
    }
}

// MARK: - RubyGems Format Steps

@Suite("Setup Steps: RubyGems Format")
struct RubyGemsSetupStepsTests {

    private let serverURL = "https://registry.example.com"
    private let serverHost = "registry.example.com"

    @Test func rubygemsGenerates2Steps() {
        let repo = makeRepo(key: "gems-local", format: "rubygems")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps.count == 2)
    }

    @Test func rubygemsBundlerStep() {
        let repo = makeRepo(key: "gems-local", format: "rubygems")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps[0].code.contains("source \""))
        #expect(steps[0].code.contains("/gems/gems-local/"))
    }

    @Test func rubygemsPushStep() {
        let repo = makeRepo(key: "gems-local", format: "rubygems")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps[1].code.contains("gem push"))
    }
}

// MARK: - Composer Format Steps

@Suite("Setup Steps: Composer Format")
struct ComposerSetupStepsTests {

    private let serverURL = "https://registry.example.com"
    private let serverHost = "registry.example.com"

    @Test func composerGenerates2Steps() {
        let repo = makeRepo(key: "php-local", format: "composer")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps.count == 2)
    }

    @Test func composerConfigStep() {
        let repo = makeRepo(key: "php-local", format: "composer")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps[0].code.contains("composer config"))
        #expect(steps[0].code.contains("/composer/php-local/"))
    }
}

// MARK: - Alpine Format Steps

@Suite("Setup Steps: Alpine Format")
struct AlpineSetupStepsTests {

    private let serverURL = "https://registry.example.com"
    private let serverHost = "registry.example.com"

    @Test func alpineGenerates2Steps() {
        let repo = makeRepo(key: "apk-local", format: "alpine")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps.count == 2)
    }

    @Test func alpineRepoStep() {
        let repo = makeRepo(key: "apk-local", format: "alpine")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps[0].code.contains("/alpine/apk-local/"))
    }
}

// MARK: - Incus/LXC Format Steps

@Suite("Setup Steps: Incus Format")
struct IncusSetupStepsTests {

    private let serverURL = "https://registry.example.com"
    private let serverHost = "registry.example.com"

    @Test func incusGenerates4Steps() {
        let repo = makeRepo(key: "incus-local", format: "incus")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps.count == 4)
    }

    @Test func incusRemoteAddStep() {
        let repo = makeRepo(key: "incus-local", format: "incus")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps[0].code.contains("incus remote add"))
        #expect(steps[0].code.contains("simplestreams"))
    }

    @Test func lxcUsesIncusSteps() {
        let repo = makeRepo(key: "lxc-local", format: "lxc")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps.count == 4)
    }
}

// MARK: - Protobuf Format Steps

@Suite("Setup Steps: Protobuf Format")
struct ProtobufSetupStepsTests {

    private let serverURL = "https://registry.example.com"
    private let serverHost = "registry.example.com"

    @Test func protobufGenerates3Steps() {
        let repo = makeRepo(key: "proto-local", format: "protobuf")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps.count == 3)
    }

    @Test func protobufBufYamlStep() {
        let repo = makeRepo(key: "proto-local", format: "protobuf")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps[0].code.contains("buf.yaml"))
        #expect(steps[0].code.contains(serverHost))
        #expect(steps[0].code.contains("/proto/proto-local/"))
    }

    @Test func protobufLoginStep() {
        let repo = makeRepo(key: "proto-local", format: "protobuf")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps[1].code.contains("buf registry login"))
    }

    @Test func protobufPushStep() {
        let repo = makeRepo(key: "proto-local", format: "protobuf")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps[2].code.contains("buf push"))
    }
}

// MARK: - Default/Unknown Format Steps

@Suite("Setup Steps: Default Format")
struct DefaultSetupStepsTests {

    private let serverURL = "https://registry.example.com"
    private let serverHost = "registry.example.com"

    @Test func unknownFormatGenerates2Steps() {
        let repo = makeRepo(key: "custom-local", format: "custom-unknown")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps.count == 2)
    }

    @Test func unknownFormatCurlUploadStep() {
        let repo = makeRepo(key: "custom-local", format: "custom-unknown")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps[0].title == "Upload an artifact")
        #expect(steps[0].code.contains("curl -X PUT"))
        #expect(steps[0].code.contains("Authorization: Bearer"))
        #expect(steps[0].code.contains("/api/v1/repositories/custom-local/"))
    }

    @Test func unknownFormatCurlDownloadStep() {
        let repo = makeRepo(key: "custom-local", format: "custom-unknown")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: serverURL, serverHost: serverHost)
        #expect(steps[1].title == "Download an artifact")
        #expect(steps[1].code.contains("curl -O"))
    }
}

// MARK: - Fallback URL Tests

@Suite("Setup Steps: URL Fallbacks")
struct SetupStepsURLFallbackTests {

    @Test func emptyServerURLUsesFallback() {
        let repo = makeRepo(key: "test-repo", format: "npm")
        let steps = SetupInstructionsHelper.steps(for: repo, serverURL: "", serverHost: "")
        #expect(steps[0].code.contains("https://artifacts.example.com"))
        #expect(steps[0].code.contains("artifacts.example.com"))
    }

    @Test func customServerURLIsUsed() {
        let repo = makeRepo(key: "test-repo", format: "npm")
        let steps = SetupInstructionsHelper.steps(
            for: repo,
            serverURL: "https://my-custom-server.io",
            serverHost: "my-custom-server.io"
        )
        #expect(steps[0].code.contains("https://my-custom-server.io"))
        #expect(steps[0].code.contains("my-custom-server.io"))
    }

    @Test func serverURLWithPortUsed() {
        let repo = makeRepo(key: "test-repo", format: "docker")
        let steps = SetupInstructionsHelper.steps(
            for: repo,
            serverURL: "https://registry.internal:8443",
            serverHost: "registry.internal:8443"
        )
        #expect(steps[0].code.contains("registry.internal:8443"))
    }

    @Test func repoKeySubstitutedCorrectly() {
        let repo = makeRepo(key: "my-special-repo", format: "cargo")
        let steps = SetupInstructionsHelper.steps(
            for: repo,
            serverURL: "https://registry.example.com",
            serverHost: "registry.example.com"
        )
        #expect(steps[0].code.contains("[registries.my-special-repo]"))
        #expect(steps[0].code.contains("/cargo/my-special-repo/index"))
        #expect(steps[1].code.contains("--registry my-special-repo"))
    }
}
