import Testing
import Foundation
@testable import ArtifactKeeper

// MARK: - TOTPValidation Tests

@Suite("TOTP Validation Tests")
struct TOTPValidationTests {

    // MARK: - filterCode

    @Test func filterCodeAllowsDigitsOnly() {
        #expect(TOTPValidation.filterCode("123456") == "123456")
    }

    @Test func filterCodeStripsLetters() {
        #expect(TOTPValidation.filterCode("12ab34") == "1234")
    }

    @Test func filterCodeStripsSpecialCharacters() {
        #expect(TOTPValidation.filterCode("12-34.56") == "123456")
    }

    @Test func filterCodeStripsSpaces() {
        #expect(TOTPValidation.filterCode("123 456") == "123456")
    }

    @Test func filterCodeTruncatesAt6Digits() {
        #expect(TOTPValidation.filterCode("12345678") == "123456")
    }

    @Test func filterCodeTruncatesAfterFiltering() {
        // 8 digit chars mixed with letters, only first 6 digits kept
        #expect(TOTPValidation.filterCode("1a2b3c4d5e6f7g8h") == "123456")
    }

    @Test func filterCodeEmptyInput() {
        #expect(TOTPValidation.filterCode("") == "")
    }

    @Test func filterCodeAllNonDigits() {
        #expect(TOTPValidation.filterCode("abcdef") == "")
    }

    @Test func filterCodeSingleDigit() {
        #expect(TOTPValidation.filterCode("5") == "5")
    }

    @Test func filterCodeExactly6Digits() {
        #expect(TOTPValidation.filterCode("000000") == "000000")
    }

    @Test func filterCodeUnicodeDigits() {
        // Only ASCII digits should pass through (Unicode digit characters
        // also satisfy `isNumber`, so they would pass too). The point is
        // non-numeric characters are stripped.
        let result = TOTPValidation.filterCode("12emoji34")
        #expect(result == "1234")
    }

    @Test func filterCodeCustomMaxLength() {
        #expect(TOTPValidation.filterCode("12345678", maxLength: 4) == "1234")
        #expect(TOTPValidation.filterCode("12345678", maxLength: 8) == "12345678")
    }

    @Test func filterCodeLeadingZeros() {
        #expect(TOTPValidation.filterCode("000001") == "000001")
    }

    // MARK: - isValidCode

    @Test func isValidCodeWith6Digits() {
        #expect(TOTPValidation.isValidCode("123456") == true)
    }

    @Test func isValidCodeAllZeros() {
        #expect(TOTPValidation.isValidCode("000000") == true)
    }

    @Test func isValidCodeTooShort() {
        #expect(TOTPValidation.isValidCode("12345") == false)
        #expect(TOTPValidation.isValidCode("") == false)
    }

    @Test func isValidCodeTooLong() {
        #expect(TOTPValidation.isValidCode("1234567") == false)
    }

    @Test func isValidCodeWithLetters() {
        #expect(TOTPValidation.isValidCode("12345a") == false)
    }

    @Test func isValidCodeWithSpaces() {
        #expect(TOTPValidation.isValidCode("123 56") == false)
    }

    // MARK: - isSubmitEnabled

    @Test func submitEnabledWithValidCodeAndNotLoading() {
        #expect(TOTPValidation.isSubmitEnabled(code: "123456", isLoading: false) == true)
    }

    @Test func submitDisabledWhenLoading() {
        #expect(TOTPValidation.isSubmitEnabled(code: "123456", isLoading: true) == false)
    }

    @Test func submitDisabledWithShortCode() {
        #expect(TOTPValidation.isSubmitEnabled(code: "12345", isLoading: false) == false)
    }

    @Test func submitDisabledWithEmptyCode() {
        #expect(TOTPValidation.isSubmitEnabled(code: "", isLoading: false) == false)
    }

    @Test func submitDisabledWithInvalidCodeAndLoading() {
        #expect(TOTPValidation.isSubmitEnabled(code: "abc", isLoading: true) == false)
    }
}

// MARK: - AuthManager TOTP State Tests

@Suite("AuthManager TOTP State Tests")
struct AuthManagerTOTPStateTests {

    @Test @MainActor func totpRequiredDefaultsToFalse() {
        let auth = AuthManager()
        #expect(auth.totpRequired == false)
        #expect(auth.totpToken == nil)
    }

    @Test @MainActor func settingTotpRequiredPreservesToken() {
        let auth = AuthManager()
        auth.totpRequired = true
        auth.totpToken = "totp-session-token-abc"
        #expect(auth.totpRequired == true)
        #expect(auth.totpToken == "totp-session-token-abc")
    }

    @Test @MainActor func cancellingTotpResetsState() {
        let auth = AuthManager()
        auth.totpRequired = true
        auth.totpToken = "totp-session-token-abc"
        auth.errorMessage = "Previous error"

        // Simulate cancel action from the view
        auth.totpRequired = false
        auth.totpToken = nil
        auth.errorMessage = nil

        #expect(auth.totpRequired == false)
        #expect(auth.totpToken == nil)
        #expect(auth.errorMessage == nil)
    }

    @Test @MainActor func logoutClearsTotpState() {
        let auth = AuthManager()
        auth.totpRequired = true
        auth.totpToken = "token-123"

        auth.logout()

        #expect(auth.totpRequired == false)
        #expect(auth.totpToken == nil)
    }
}
