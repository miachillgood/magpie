//
//  APIKeySetupView.swift
//  SnapLingo
//
//  首次启动或 API Key 失效时显示的配置页
//

import SwiftUI

struct APIKeySetupView: View {
    @Binding var isPresented: Bool
    @State private var keyInput = ""
    @State private var isSaving = false
    @State private var showError = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                // 图标
                Image(systemName: "key.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                    .padding(.top, 16)

                // 说明
                VStack(spacing: 8) {
                    Text("配置 Claude API Key")
                        .font(.title2.bold())
                    Text("SnapLingo 使用 Claude AI 分析词汇。\n请前往 console.anthropic.com 获取 API Key。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // 输入框
                VStack(alignment: .leading, spacing: 6) {
                    Text("API Key")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    SecureField("sk-ant-api03-…", text: $keyInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                }
                .padding(.horizontal)

                if showError {
                    Text("Key 格式不正确，请检查后重试")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Spacer()

                // 保存按钮
                Button {
                    saveKey()
                } label: {
                    Group {
                        if isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Text("保存并继续")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(keyInput.isEmpty ? Color.secondary.opacity(0.3) : Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(keyInput.isEmpty || isSaving)
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 已有 Key 时可取消
                if KeychainHelper.hasAPIKey {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { isPresented = false }
                    }
                }
            }
        }
    }

    private func saveKey() {
        let trimmed = keyInput.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("sk-ant") else {
            showError = true
            return
        }
        showError = false
        isSaving = true
        KeychainHelper.saveAPIKey(trimmed)
        isSaving = false
        isPresented = false
    }
}

#Preview {
    APIKeySetupView(isPresented: .constant(true))
}
