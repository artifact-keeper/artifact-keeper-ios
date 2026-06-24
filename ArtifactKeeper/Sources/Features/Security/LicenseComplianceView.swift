import SwiftUI

/// Check a set of SPDX license identifiers against policy
/// (POST /api/v1/sbom/check-compliance). The operator types one license per
/// line and runs the check; the result lists violations and warnings.
struct LicenseComplianceView: View {
    @State private var licensesText = ""
    @State private var isChecking = false
    @State private var result: LicenseCheckResult?
    @State private var errorMessage: String?

    private let apiClient = APIClient.shared

    private var licenses: [String] {
        licensesText
            .split(whereSeparator: { $0 == "\n" || $0 == "," })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        Form {
            Section("Licenses") {
                #if os(iOS)
                TextEditor(text: $licensesText)
                    .frame(minHeight: 120)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                #else
                TextEditor(text: $licensesText)
                    .frame(minHeight: 120)
                #endif
                Text("One license per line or comma separated (e.g. MIT, GPL-3.0, Apache-2.0).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button {
                    Task { await check() }
                } label: {
                    if isChecking {
                        ProgressView()
                    } else {
                        Text("Check Compliance")
                    }
                }
                .disabled(licenses.isEmpty || isChecking)
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }

            if let result {
                Section("Result") {
                    HStack {
                        Image(systemName: result.compliant ? "checkmark.seal.fill" : "xmark.seal.fill")
                            .foregroundStyle(result.compliant ? Color.green : Color.red)
                        Text(result.compliant ? "Compliant" : "Not Compliant")
                            .font(.headline)
                    }
                }

                if !result.violations.isEmpty {
                    Section("Violations") {
                        ForEach(result.violations, id: \.self) { violation in
                            Label(violation, systemImage: "xmark.octagon")
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }
                    }
                }

                if !result.warnings.isEmpty {
                    Section("Warnings") {
                        ForEach(result.warnings, id: \.self) { warning in
                            Label(warning, systemImage: "exclamationmark.triangle")
                                .font(.subheadline)
                                .foregroundStyle(.orange)
                        }
                    }
                }

                if result.compliant && result.violations.isEmpty && result.warnings.isEmpty {
                    Section {
                        Text("All licenses pass the active policy.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func check() async {
        isChecking = true
        errorMessage = nil
        defer { isChecking = false }
        do {
            result = try await apiClient.checkLicenseCompliance(licenses: licenses)
        } catch {
            result = nil
            errorMessage = "Compliance check failed: \(error.localizedDescription)"
        }
    }
}
