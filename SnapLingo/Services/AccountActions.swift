//
//  AccountActions.swift
//  SnapLingo
//
//  登录页要调用的操作。界面只依赖这几个闭包：阶段 D 换成 Supabase 的实现，
//  在那之前只有调试版里的假实现（-previewAccounts），用来预览界面。
//

import Foundation

struct AccountActions {
    /// 给 E.164 格式的号码发验证码
    var sendPhoneCode: (_ phone: String) async throws -> Void
    var sendEmailCode: (_ email: String) async throws -> Void
    var verifyPhoneCode: (_ phone: String, _ code: String) async throws -> Void
    var verifyEmailCode: (_ email: String, _ code: String) async throws -> Void
}

enum AccountError: LocalizedError {
    case wrongCode
    case sendFailed

    var errorDescription: String? {
        switch self {
        case .wrongCode: String(localized: "验证码不对，再试一次")
        case .sendFailed: String(localized: "没能发送验证码，请检查网络后再试")
        }
    }
}

#if DEBUG
extension AccountActions {
    /// 调试预览：发码等 0.8 秒，验证码 123456 算对
    static let preview = AccountActions(
        sendPhoneCode: { _ in try await Task.sleep(for: .milliseconds(800)) },
        sendEmailCode: { _ in try await Task.sleep(for: .milliseconds(800)) },
        verifyPhoneCode: { _, code in
            try await Task.sleep(for: .milliseconds(600))
            if code != "123456" { throw AccountError.wrongCode }
        },
        verifyEmailCode: { _, code in
            try await Task.sleep(for: .milliseconds(600))
            if code != "123456" { throw AccountError.wrongCode }
        }
    )
}
#endif
