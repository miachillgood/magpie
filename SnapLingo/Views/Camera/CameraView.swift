//
//  CameraView.swift
//  SnapLingo
//

import SwiftUI
import PhotosUI

struct CameraView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @State private var viewModel = CameraViewModel()
    @State private var showImagePicker = false
    @State private var showPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        @Bindable var coordinator = coordinator

        ZStack {
            // 背景
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Logo 区域
                VStack(spacing: 12) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 64))
                        .foregroundStyle(.tint)
                    Text("拍照识词")
                        .font(.title2.bold())
                    Text("拍摄含有英文的照片\nAI 自动筛选关键词汇")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                // 操作按钮
                VStack(spacing: 16) {
                    // 拍照按钮
                    Button {
                        showImagePicker = true
                    } label: {
                        Label("拍照", systemImage: "camera.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.tint)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    // 从相册选择
                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: .images
                    ) {
                        Label("从相册选择", systemImage: "photo.on.rectangle")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.secondary.opacity(0.15))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }

            // 处理中遮罩
            if viewModel.isProcessing {
                LoadingOverlayView(message: "正在识别文字…")
            }
        }
        // 相机（UIImagePickerController）
        .fullScreenCover(isPresented: $showImagePicker) {
            ImagePickerView { image in
                showImagePicker = false
                Task { await viewModel.processImage(image) }
            }
            .ignoresSafeArea()
        }
        // 从相册选图
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await viewModel.processImage(image)
                }
                selectedPhotoItem = nil
            }
        }
        // 错误提示
        .alert("识别失败", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("好") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        // OCR 完成 → 推进到词汇筛选
        .onChange(of: viewModel.navigateToWordSelection) { _, ready in
            guard ready,
                  let ocrResult = viewModel.ocrResult,
                  let image = viewModel.capturedImage else { return }
            coordinator.scanPath.append(
                ScanRoute.wordSelection(ocrResult: ocrResult, image: image)
            )
            viewModel.navigateToWordSelection = false
        }
        .navigationDestination(for: ScanRoute.self) { route in
            switch route {
            case .wordSelection(let ocrResult, let image):
                WordSelectionView(ocrResult: ocrResult, sourceImage: image)
            }
        }
    }
}

// MARK: - 导航路由

enum ScanRoute: Hashable {
    case wordSelection(ocrResult: OCRResult, image: UIImage)

    // Hashable 手动实现（OCRResult 和 UIImage 不自动 conform）
    func hash(into hasher: inout Hasher) {
        switch self {
        case .wordSelection(_, let img):
            hasher.combine(ObjectIdentifier(img))
        }
    }

    static func == (lhs: ScanRoute, rhs: ScanRoute) -> Bool {
        switch (lhs, rhs) {
        case (.wordSelection(_, let a), .wordSelection(_, let b)):
            return a === b
        }
    }
}

