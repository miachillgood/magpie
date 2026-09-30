//
//  ProfileHeader.swift
//  SnapLingo
//
//  「我的」顶部：头像（点一下换）、昵称（点一下改）、登录状态；没登录时下面是「通过 Apple 登录」。
//

import AuthenticationServices
import PhotosUI
import SwiftData
import SwiftUI

struct ProfileHeader: View {
    var settings: UserSettings
    var onAvatar: () -> Void
    var onName: () -> Void
    var onSignIn: (Result<ASAuthorization, Error>) -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                Button(action: onAvatar) {
                    AvatarView(settings: settings, size: 76, showsBadge: true)
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("更换头像")

                VStack(alignment: .leading, spacing: 4) {
                    Button(action: onName) {
                        HStack(spacing: 8) {
                            if settings.nickname.isEmpty {
                                Text("给自己起个名字")
                                    .font(.system(size: 22, weight: .heavy))
                            } else {
                                Text(settings.nickname)
                                    .font(.system(size: 26, weight: .heavy))
                            }
                            Image(systemName: "pencil")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.homeMuted)
                        }
                        .foregroundStyle(Theme.homeInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("修改昵称")

                    if settings.isSignedIn {
                        Label("已通过 Apple 登录", systemImage: "apple.logo")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.homeInk.opacity(0.7))
                    } else {
                        Text("还没登录 · 数据只存在这台手机上")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.homeInk.opacity(0.7))
                    }
                }
                Spacer(minLength: 0)
            }

            if !settings.isSignedIn {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    onSignIn(result)
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 50)
                .clipShape(.capsule)
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - 头像

/// 圆形头像：有照片显示照片，没有就显示昵称首字母（没有昵称显示 ?）
struct AvatarView: View {
    var settings: UserSettings
    var size: CGFloat
    var showsBadge = false

    var body: some View {
        face
            .frame(width: size, height: size)
            .clipShape(.circle)
            .overlay(Circle().stroke(Theme.sheet, lineWidth: 4))
            .shadow(color: .black.opacity(0.12), radius: 10, y: 6)
            .overlay(alignment: .bottomTrailing) {
                if showsBadge {
                    Image(systemName: "camera")
                        .font(.system(size: size * 0.18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: size * 0.36, height: size * 0.36)
                        .background(Theme.homeInk, in: .circle)
                        .overlay(Circle().stroke(Theme.sheet, lineWidth: 3))
                        .offset(x: 2, y: 2)
                }
            }
    }

    @ViewBuilder
    private var face: some View {
        if let data = settings.avatarData, let image = ImageCache.shared.image(for: "avatar-\(data.count)-\(data.hashValue)", data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Text(AvatarView.initial(of: settings.nickname))
                .font(.brand(size * 0.42))
                .foregroundStyle(Theme.homeInk)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.marker)
        }
    }

    /// 昵称的第一个字（中日韩取第一个字，拉丁文字取首字母大写）
    static func initial(of name: String) -> String {
        guard let first = name.trimmingCharacters(in: .whitespacesAndNewlines).first else { return "?" }
        return String(first).uppercased()
    }
}

// MARK: - 换头像

struct AvatarPickerSheet: View {
    var settings: UserSettings

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var photoItem: PhotosPickerItem?
    @State private var showingCamera = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("更换头像")
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(Theme.homeInk)
                .padding(.bottom, 6)

            PhotosPicker(selection: $photoItem, matching: .images) {
                optionLabel(Image(systemName: "photo"), "从相册选一张")
            }
            .buttonStyle(.pressable)

            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button { showingCamera = true } label: {
                    optionLabel(Image(systemName: "camera"), "拍一张")
                }
                .buttonStyle(.pressable)
            }

            Button {
                settings.avatarData = nil
                try? context.save()
                dismiss()
            } label: {
                HStack(spacing: 12) {
                    Text(AvatarView.initial(of: settings.nickname))
                        .font(.brand(12))
                        .frame(width: 24, height: 24)
                        .background(Theme.marker, in: .circle)
                    Text("用名字首字母")
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                }
                .foregroundStyle(Theme.homeInk)
                .padding(.horizontal, 16)
                .frame(height: 56)
                .background(Theme.mist, in: .rect(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.pressable)

            Text("头像只存在这台手机上")
                .font(.system(size: 12))
                .foregroundStyle(Theme.homeMuted)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.sheet)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    save(image)
                }
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            SystemCameraPicker { image in
                showingCamera = false
                if let image { save(image) }
            }
            .ignoresSafeArea()
        }
    }

    private func optionLabel(_ icon: Image, _ title: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            icon
                .font(.system(size: 18, weight: .medium))
                .frame(width: 24)
            Text(title)
                .font(.system(size: 16, weight: .semibold))
            Spacer()
        }
        .foregroundStyle(Theme.homeInk)
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(Theme.mist, in: .rect(cornerRadius: 18, style: .continuous))
    }

    /// 裁成正方形、缩到 512 再保存
    private func save(_ image: UIImage) {
        let side = min(image.size.width, image.size.height)
        let crop = CGRect(x: (image.size.width - side) / 2, y: (image.size.height - side) / 2, width: side, height: side)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let square = UIGraphicsImageRenderer(size: CGSize(width: 512, height: 512), format: format).image { _ in
            image.draw(in: CGRect(x: -crop.minX * 512 / side, y: -crop.minY * 512 / side, width: image.size.width * 512 / side, height: image.size.height * 512 / side))
        }
        settings.avatarData = square.jpegData(compressionQuality: 0.85)
        try? context.save()
        dismiss()
    }
}
