import SwiftUI

struct WelcomeView: View {
    var onComplete: () -> Void

    @AppStorage(APIClient.serverURLKey) private var savedServerURL: String = ""
    @State private var serverURL: String = ""
    @State private var isConnecting = false
    @State private var errorMessage: String?
    @FocusState private var isURLFieldFocused: Bool

    private let apiClient = APIClient.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 60)

                // Logo area
                logoSection
                    .padding(.bottom, 32)

                // Title
                Text("Welcome to Artifact Keeper")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 8)

                // Subtitle
                Text("Connect to your Artifact Keeper server to browse repositories, packages, and builds.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)

                // Form
                connectionForm
                    .padding(.horizontal, 24)

                Spacer()
                    .frame(height: 40)

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
                .padding(.bottom, 24)
            }
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
        .background(AppTheme.background)
    }

    // MARK: - Logo

    @ViewBuilder
    private var logoSection: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [AppTheme.primary, AppTheme.secondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 100, height: 100)
                .shadow(color: AppTheme.primary.opacity(0.3), radius: 16, y: 8)

            Image(systemName: "shippingbox.fill")
                .font(.system(size: 44))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Connection Form

    @ViewBuilder
    private var connectionForm: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Server URL")
                    .font(.subheadline)
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
                .padding(.vertical, 12)
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
