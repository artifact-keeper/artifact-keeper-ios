import SwiftUI

struct WelcomeView: View {
    var onComplete: () -> Void

    @EnvironmentObject var serverManager: ServerManager
    @AppStorage(APIClient.serverURLKey) private var savedServerURL: String = ""
    @State private var serverURL: String = ""
    @State private var isConnecting = false
    @State private var errorMessage: String?
    @FocusState private var isURLFieldFocused: Bool

    private let apiClient = APIClient.shared

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer()

                    // Logo area
                    logoSection
                        .padding(.bottom, 24)

                    // Title
                    Text("Welcome to Artifact Keeper")
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 6)

                    // Subtitle
                    Text("Connect to your Artifact Keeper server to browse repositories, packages, and builds.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 32)

                    // Form
                    connectionForm
                        .padding(.horizontal, 32)

                    Spacer()

                    // Learn More
                    Link(destination: URL(string: "https://artifactkeeper.com")!) {
                        HStack(spacing: 4) {
                            Text("Learn More")
                                .font(.footnote)
                            Image(systemName: "arrow.up.right")
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 20)
                }
                .frame(maxWidth: 400)
                .frame(maxWidth: .infinity)
                .frame(minHeight: geo.size.height)
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
    }

    // MARK: - Logo

    @ViewBuilder
    private var logoSection: some View {
        Image("Logo")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 96, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
    }

    // MARK: - Connection Form

    @ViewBuilder
    private var connectionForm: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Server URL")
                    .font(.footnote)
                    .fontWeight(.medium)

                TextField("https://artifacts.example.com", text: $serverURL)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .focused($isURLFieldFocused)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    #endif
                    .onSubmit {
                        connect()
                    }
            }

            // Error message
            if let errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(AppTheme.error)
                        .font(.caption)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(AppTheme.error)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Connect button
            Button(action: connect) {
                HStack(spacing: 8) {
                    if isConnecting {
                        ProgressView()
                            .controlSize(.small)
                            #if os(iOS)
                            .tint(.white)
                            #endif
                    }
                    Text(isConnecting ? "Connecting..." : "Connect")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.primary)
            .disabled(isConnecting || serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    // MARK: - Actions

    private func connect() {
        let trimmed = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed

        guard !cleaned.isEmpty else {
            withAnimation { errorMessage = "Please enter a server URL." }
            return
        }

        guard let url = URL(string: cleaned),
              let scheme = url.scheme,
              (scheme == "http" || scheme == "https"),
              url.host != nil else {
            withAnimation { errorMessage = "Enter a valid URL starting with http:// or https://" }
            return
        }

        isConnecting = true
        errorMessage = nil

        Task {
            do {
                try await apiClient.testConnection(to: cleaned)
                await apiClient.updateBaseURL(cleaned)
                await MainActor.run {
                    let host = URL(string: cleaned)?.host ?? "Server"
                    let name = (host == "localhost" || host == "127.0.0.1") ? "Local" : host
                    serverManager.addServer(name: name, url: cleaned)
                    savedServerURL = cleaned
                    onComplete()
                }
            } catch let error as URLError {
                await MainActor.run {
                    isConnecting = false
                    withAnimation {
                        switch error.code {
                        case .notConnectedToInternet:
                            errorMessage = "No internet connection. Check your network and try again."
                        case .timedOut:
                            errorMessage = "Connection timed out. Verify the server URL and try again."
                        case .cannotFindHost:
                            errorMessage = "Server not found. Check the URL and try again."
                        case .cannotConnectToHost:
                            errorMessage = "Cannot connect to server. Make sure it is running."
                        case .secureConnectionFailed:
                            errorMessage = "SSL/TLS error. Check the server's certificate configuration."
                        default:
                            errorMessage = "Connection failed: \(error.localizedDescription)"
                        }
                    }
                }
            } catch let error as APIError {
                await MainActor.run {
                    isConnecting = false
                    withAnimation {
                        errorMessage = "Server responded with an error: \(error.localizedDescription)"
                    }
                }
            } catch {
                await MainActor.run {
                    isConnecting = false
                    withAnimation {
                        errorMessage = "Connection failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
}
