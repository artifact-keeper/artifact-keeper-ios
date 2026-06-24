import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Repository-scoped access tokens for a single repository
/// (/api/v1/repositories/{key}/tokens). Lists tokens, creates a new one (the
/// secret is shown once), and revokes a token behind a confirmation.
struct RepoTokensView: View {
    let repoKey: String

    @State private var tokens: [RepoToken] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    @State private var showCreate = false
    @State private var createdToken: CreateRepoTokenResponse?
    @State private var tokenToRevoke: RepoToken?
    @State private var isRevoking = false

    private let apiClient = APIClient.shared

    var body: some View {
        List {
            if let createdToken {
                Section("New Token Created") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Copy this token now \u{2014} it will not be shown again.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(createdToken.token)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                        Button {
                            copyToClipboard(createdToken.token)
                        } label: {
                            Label("Copy Token", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section {
                if isLoading {
                    ProgressView()
                } else if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if tokens.isEmpty {
                    ContentUnavailableView(
                        "No Tokens",
                        systemImage: "key",
                        description: Text("Create a token for programmatic access to this repository.")
                    )
                } else {
                    ForEach(tokens) { token in
                        RepoTokenRow(token: token) {
                            tokenToRevoke = token
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Repository Tokens")
                    Spacer()
                    Button {
                        showCreate = true
                    } label: {
                        Label("Create", systemImage: "plus")
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .refreshable { await load() }
        .task { await load() }
        .sheet(isPresented: $showCreate) {
            NavigationStack {
                CreateRepoTokenView(repoKey: repoKey) { created in
                    createdToken = created
                    await load()
                }
            }
        }
        .confirmationDialog(
            "Revoke \(tokenToRevoke?.name ?? "token")?",
            isPresented: Binding(
                get: { tokenToRevoke != nil },
                set: { if !$0 { tokenToRevoke = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Revoke", role: .destructive) {
                if let token = tokenToRevoke {
                    Task { await revoke(token) }
                }
            }
            Button("Cancel", role: .cancel) { tokenToRevoke = nil }
        } message: {
            Text("Revoking immediately disables this token. This cannot be undone.")
        }
    }

    private func load() async {
        isLoading = tokens.isEmpty
        do {
            tokens = try await apiClient.listRepoTokens(repoKey: repoKey)
            errorMessage = nil
        } catch {
            if tokens.isEmpty {
                errorMessage = "Could not load tokens. You may need admin privileges."
            }
        }
        isLoading = false
    }

    private func revoke(_ token: RepoToken) async {
        isRevoking = true
        defer { isRevoking = false; tokenToRevoke = nil }
        do {
            try await apiClient.revokeRepoToken(repoKey: repoKey, tokenId: token.id)
            await load()
        } catch {
            errorMessage = "Failed to revoke \(token.name): \(error.localizedDescription)"
        }
    }

    private func copyToClipboard(_ value: String) {
        #if os(iOS)
        UIPasteboard.general.string = value
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        #endif
    }
}

private struct RepoTokenRow: View {
    let token: RepoToken
    let onRevoke: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(token.name).font(.headline)
                if token.isRevoked {
                    statusTag("Revoked", .red)
                } else if token.isExpired {
                    statusTag("Expired", .orange)
                }
                Spacer()
                if !token.isRevoked {
                    Button(role: .destructive, action: onRevoke) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }
            }
            Text(token.tokenPrefix + "\u{2026}")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
            if !token.scopes.isEmpty {
                HStack(spacing: 4) {
                    ForEach(token.scopes, id: \.self) { scope in
                        Text(scope)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.secondary.opacity(0.15), in: Capsule())
                    }
                }
            }
            if let expiresAt = token.expiresAt {
                Text("Expires \(formattedDate(expiresAt))")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func statusTag(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}

/// Create-token sheet: name, scopes, expiry.
private struct CreateRepoTokenView: View {
    let repoKey: String
    let onCreated: (CreateRepoTokenResponse) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var scopes: Set<String> = ["read"]
    @State private var expiryDays = 90
    @State private var isCreating = false
    @State private var errorMessage: String?

    private let apiClient = APIClient.shared
    private let availableScopes = ["read", "write", "delete", "admin"]
    private let expiryOptions: [(String, Int)] = [
        ("30 days", 30), ("90 days", 90), ("180 days", 180), ("1 year", 365), ("Never", 0),
    ]

    var body: some View {
        Form {
            Section("Token") {
                TextField("Name", text: $name)
                    #if os(iOS)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    #endif
            }

            Section("Scopes") {
                ForEach(availableScopes, id: \.self) { scope in
                    Toggle(scope.capitalized, isOn: Binding(
                        get: { scopes.contains(scope) },
                        set: { on in
                            if on { scopes.insert(scope) } else { scopes.remove(scope) }
                        }
                    ))
                }
            }

            Section("Expiry") {
                Picker("Expires", selection: $expiryDays) {
                    ForEach(expiryOptions, id: \.1) { option in
                        Text(option.0).tag(option.1)
                    }
                }
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Create Token")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .disabled(isCreating)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") { Task { await create() } }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || scopes.isEmpty || isCreating)
            }
        }
    }

    private func create() async {
        isCreating = true
        errorMessage = nil
        defer { isCreating = false }
        do {
            let result = try await apiClient.createRepoToken(
                repoKey: repoKey,
                name: name.trimmingCharacters(in: .whitespaces),
                scopes: Array(scopes).sorted(),
                expiresInDays: expiryDays == 0 ? nil : expiryDays
            )
            await onCreated(result)
            dismiss()
        } catch {
            errorMessage = "Could not create token: \(error.localizedDescription)"
        }
    }
}

private func formattedDate(_ dateString: String) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: dateString) {
        let display = DateFormatter()
        display.dateStyle = .medium
        return display.string(from: date)
    }
    return dateString
}
