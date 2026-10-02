//
//  ContactEntryViews.swift
//  SnapLingo
//
//  输入手机号 / 邮箱，发验证码。
//

import SwiftUI

struct PhoneEntryView: View {
    var onBack: () -> Void
    /// 发码成功后进入输入验证码：(E.164 号码, 打码后的显示文字)
    var send: (_ phone: String, _ masked: String) async throws -> Void

    @State private var region = PhoneRegion.defaultRegion(for: Locale.current.region?.identifier)
    @State private var number = ""
    @State private var sending = false
    @State private var error: String?
    @FocusState private var focused: Bool

    private var phone: String? { AccountInput.e164(national: number, region: region) }

    /// 支持的地区名，按界面语言连起来：新西兰、澳大利亚……和爱尔兰
    private var regionList: String {
        ListFormatter.localizedString(byJoining: PhoneRegion.supported.map { $0.name() })
    }

    var body: some View {
        AccountScaffold(title: "用手机号登录", subtitle: Text("我们会发一条 6 位验证码到你的手机。"), onBack: onBack) {
            VStack(alignment: .leading, spacing: 14) {
                AccountFieldCard(label: "手机号") {
                    Menu {
                        Picker(selection: $region) {
                            ForEach(PhoneRegion.supported) { item in
                                Text(verbatim: "\(PhoneEntryView.flag(item.code)) \(item.name())  +\(item.dialCode)").tag(item)
                            }
                        } label: {
                            Text("地区")
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(verbatim: "\(PhoneEntryView.flag(region.code)) +\(region.dialCode)")
                            Image(systemName: "chevron.down").font(.system(size: 11, weight: .bold))
                        }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.homeInk)
                        .padding(.horizontal, 10)
                        .frame(height: 40)
                        .background(Theme.sheet, in: .rect(cornerRadius: 12, style: .continuous))
                    }
                    .accessibilityLabel(Text("地区：\(region.name())，区号 +\(region.dialCode)"))

                    TextField("手机号", text: $number)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(Theme.homeInk)
                        .focused($focused)
                        .onChange(of: number) { error = nil }
                }

                AccountNote(text: error ?? String(localized: "支持这些地区的号码：\(regionList)。"), isError: error != nil)

                AccountPrimaryButton(title: "获取验证码", enabled: phone != nil, busy: sending) { submit() }
                    .padding(.top, 6)
            }
        }
        .onAppear { focused = true }
    }

    private func submit() {
        guard let phone, !sending else { return }
        sending = true
        Task {
            defer { sending = false }
            do {
                try await send(phone, AccountInput.maskedPhone(phone, region: region))
            } catch {
                self.error = (error as? LocalizedError)?.errorDescription ?? AccountError.sendFailed.localizedDescription
            }
        }
    }

    /// 地区代码转国旗：NZ → 🇳🇿
    static func flag(_ code: String) -> String {
        code.uppercased().unicodeScalars
            .compactMap { UnicodeScalar(127_397 + $0.value) }
            .map(String.init)
            .joined()
    }
}

struct EmailEntryView: View {
    var onBack: () -> Void
    /// 发码成功后进入输入验证码：(邮箱, 打码后的显示文字)
    var send: (_ email: String, _ masked: String) async throws -> Void

    @State private var email = ""
    @State private var sending = false
    @State private var error: String?
    @FocusState private var focused: Bool

    private var isValid: Bool { AccountInput.isValidEmail(email) }

    var body: some View {
        AccountScaffold(title: "用邮箱登录", subtitle: Text("我们会发一封带 6 位验证码的邮件。"), onBack: onBack) {
            VStack(alignment: .leading, spacing: 14) {
                AccountFieldCard(label: "邮箱") {
                    TextField(text: $email) {
                        Text(verbatim: "name@example.com")
                    }
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.homeInk)
                    .padding(.horizontal, 6)
                    .focused($focused)
                    .submitLabel(.send)
                    .onSubmit { submit() }
                    .onChange(of: email) { error = nil }
                }

                AccountNote(text: error ?? String(localized: "验证码 10 分钟内有效。没收到的话，看看垃圾邮件文件夹。"), isError: error != nil)

                AccountPrimaryButton(title: "发送验证码", enabled: isValid, busy: sending) { submit() }
                    .padding(.top, 6)
            }
        }
        .onAppear { focused = true }
    }

    private func submit() {
        guard isValid, !sending else { return }
        let address = AccountInput.normalizedEmail(email)
        sending = true
        Task {
            defer { sending = false }
            do {
                try await send(address, AppleAccount.maskedEmail(address))
            } catch {
                self.error = (error as? LocalizedError)?.errorDescription ?? AccountError.sendFailed.localizedDescription
            }
        }
    }
}
