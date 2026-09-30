//
//  AccountTests.swift
//  SnapLingoTests
//

import Foundation
import Testing
@testable import SnapLingo

// MARK: - 引导顺序

@MainActor
struct OnboardingFlowTests {
    @Test func levelTestComesRightAfterWelcomeWithoutAccounts() {
        #expect(OnboardingFlow.steps(accountsEnabled: false) == [.welcome, .level, .language, .ai, .pace, .reminder])
        #expect(OnboardingFlow.next(after: .welcome, accountsEnabled: false) == .level)
    }

    @Test func loginSitsBetweenWelcomeAndLevelTest() {
        #expect(OnboardingFlow.steps(accountsEnabled: true) == [.welcome, .login, .level, .language, .ai, .pace, .reminder])
        #expect(OnboardingFlow.next(after: .welcome, accountsEnabled: true) == .login)
        #expect(OnboardingFlow.next(after: .login, accountsEnabled: true) == .level)
    }

    @Test func reminderIsLast() {
        #expect(OnboardingFlow.next(after: .reminder, accountsEnabled: true) == nil)
        #expect(OnboardingFlow.next(after: .reminder, accountsEnabled: false) == nil)
    }
}

// MARK: - 登录输入

@MainActor
struct AccountInputTests {
    private let nz = PhoneRegion.defaultRegion(for: "NZ")
    private let uk = PhoneRegion.defaultRegion(for: "GB")

    @Test func phoneNumbersBecomeE164() {
        #expect(AccountInput.e164(national: "021 234 5678", region: nz) == "+64212345678")
        #expect(AccountInput.e164(national: "21-234-5678", region: nz) == "+64212345678")
        // 连区号一起输入也认
        #expect(AccountInput.e164(national: "+64 21 234 5678", region: nz) == "+64212345678")
        #expect(AccountInput.e164(national: "07911 123456", region: uk) == "+447911123456")
        #expect(AccountInput.e164(national: "44 7911 123456", region: uk) == "+447911123456")
    }

    @Test func tooShortOrTooLongNumbersAreRejected() {
        #expect(AccountInput.e164(national: "12345", region: nz) == nil)
        #expect(AccountInput.e164(national: "", region: nz) == nil)
        #expect(AccountInput.e164(national: "1234567890123", region: nz) == nil)
    }

    @Test func maskedPhoneKeepsOnlyTheEnds() {
        #expect(AccountInput.maskedPhone("+64212345678", region: nz) == "+64 21 •••• 678")
    }

    @Test func defaultRegionFollowsTheDeviceAndFallsBackToNewZealand() {
        #expect(PhoneRegion.defaultRegion(for: "AU").dialCode == "61")
        #expect(PhoneRegion.defaultRegion(for: "au").code == "AU")
        #expect(PhoneRegion.defaultRegion(for: "CN").code == "NZ")
        #expect(PhoneRegion.defaultRegion(for: nil).code == "NZ")
    }

    @Test func emailValidation() {
        #expect(AccountInput.isValidEmail("mia@example.com"))
        #expect(AccountInput.isValidEmail("  mia.m+words@uni.ac.nz "))
        #expect(!AccountInput.isValidEmail("mia@example"))
        #expect(!AccountInput.isValidEmail("mia example.com"))
        #expect(!AccountInput.isValidEmail("@example.com"))
        #expect(AccountInput.normalizedEmail(" Mia@Example.COM ") == "mia@example.com")
    }

    @Test func codesKeepSixDigitsOnly() {
        #expect(AccountInput.sanitizedCode("12 34 56") == "123456")
        #expect(AccountInput.sanitizedCode("Your code is 482913.") == "482913")
        #expect(AccountInput.sanitizedCode("1234567") == "123456")
        #expect(AccountInput.sanitizedCode("１２３") == "")
    }
}
