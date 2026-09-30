//
//  AppleAccount.swift
//  SnapLingo
//
//  「通过 Apple 登录」：只记住你是谁（Apple 用户标识、名字、邮箱），不连服务器、不同步。
//  不登录也能正常使用；退出登录不删除任何场景和单词。
//

import AuthenticationServices
import SwiftData

enum AppleAccount {
    enum Outcome {
        case signedIn
        case cancelled
        case failed(String)
    }

    /// 处理 SignInWithAppleButton 的结果
    static func handle(_ result: Result<ASAuthorization, Error>, settings: UserSettings, context: ModelContext) -> Outcome {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                return .failed(String(localized: "没能读取 Apple 登录信息，请再试一次。"))
            }
            settings.appleUserID = credential.user
            // Apple 只在第一次授权时给名字和邮箱，之后为空，所以只在有值时覆盖
            if let email = credential.email, !email.isEmpty {
                settings.appleEmail = email
            }
            let name = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            if settings.nickname.isEmpty && !name.isEmpty {
                settings.nickname = name
            }
            try? context.save()
            return .signedIn

        case .failure(let error):
            let nsError = error as NSError
            if nsError.domain == ASAuthorizationError.errorDomain, nsError.code == ASAuthorizationError.canceled.rawValue {
                return .cancelled
            }
            return .failed(String(localized: "登录没有成功：\(error.localizedDescription)"))
        }
    }

    /// 退出登录：只清掉账号信息，场景、单词、头像和昵称都保留
    static func signOut(settings: UserSettings, context: ModelContext) {
        settings.appleUserID = ""
        settings.appleEmail = ""
        try? context.save()
    }

    /// 启动时确认登录还有效；在「设置 → Apple 账户」里撤销过就自动退出。
    /// 模拟器和开发环境里查询可能失败，这时保留登录状态
    static func refreshCredentialState(settings: UserSettings, context: ModelContext) async {
        let userID = settings.appleUserID
        guard !userID.isEmpty else { return }
        let state: ASAuthorizationAppleIDProvider.CredentialState? = await withCheckedContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userID) { state, error in
                continuation.resume(returning: error == nil ? state : nil)
            }
        }
        if let state, state == .revoked || state == .notFound {
            signOut(settings: settings, context: context)
        }
    }

    /// 邮箱中间打码：mia•••@icloud.com
    static func maskedEmail(_ email: String) -> String {
        let parts = email.split(separator: "@", maxSplits: 1)
        guard parts.count == 2 else { return email }
        let name = parts[0]
        let visible = name.prefix(min(3, max(1, name.count - 1)))
        return "\(visible)•••@\(parts[1])"
    }
}
