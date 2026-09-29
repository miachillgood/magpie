//
//  ScanCameraView.swift
//  SnapLingo
//

import AVFoundation
import PhotosUI
import SwiftUI
import VisionKit

/// 取景页：支持的设备用 VisionKit 实时文字高亮，否则从相册选图
struct ScanCameraView: View {
    var onCapture: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var scanner = LiveScannerController()
    @State private var photoItem: PhotosPickerItem?
    @State private var isCapturing = false
    @State private var showingSystemCamera = false
    @State private var loadError: String?
    /// 先确认相机权限再决定是否实时取景（未授权时 isAvailable 为 false）
    @State private var cameraChecked = false
    @State private var cameraDenied = false

    private var liveScanAvailable: Bool {
        cameraChecked && DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if liveScanAvailable {
                LiveTextScanner(controller: scanner)
                    .ignoresSafeArea()
            } else if cameraChecked {
                fallback
            }
        }
        .task { await checkCamera() }
        .overlay(alignment: .top) { hint }
        .overlay(alignment: .bottom) {
            if liveScanAvailable { controls }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("关闭", systemImage: "xmark") { dismiss() }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .environment(\.colorScheme, .dark)
        .statusBarHidden()
        .sensoryFeedback(.impact(weight: .medium), trigger: isCapturing) { _, new in new }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await load(item) }
        }
        .fullScreenCover(isPresented: $showingSystemCamera) {
            SystemCameraPicker { image in
                showingSystemCamera = false
                if let image { onCapture(image) }
            }
            .ignoresSafeArea()
        }
        .alert("无法读取照片", isPresented: Binding(get: { loadError != nil }, set: { if !$0 { loadError = nil } })) {
            Button("好", role: .cancel) {}
        } message: {
            Text(loadError ?? "")
        }
    }

    // MARK: - 提示

    @ViewBuilder
    private var hint: some View {
        if liveScanAvailable {
            Text(scanner.recognizedCount > 0 ? "找到 \(scanner.recognizedCount) 段文字，按下快门" : "对准身边的英文文字")
                .font(.subheadline.weight(.semibold))
                .contentTransition(.numericText())
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .glassEffect(.regular, in: .capsule)
                .padding(.top, Spacing.xs)
                .animation(.snappy, value: scanner.recognizedCount)
        }
    }

    // MARK: - 底部按钮

    private var controls: some View {
        HStack(alignment: .center) {
            PhotosPicker(selection: $photoItem, matching: .images) {
                Image(systemName: "photo.on.rectangle")
                    .font(.title2)
                    .frame(width: 56, height: 56)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("从相册选择")

            Spacer()

            if liveScanAvailable {
                Button {
                    capture()
                } label: {
                    ZStack {
                        Circle().fill(.white).frame(width: 64, height: 64)
                        Circle().strokeBorder(.white.opacity(0.6), lineWidth: 4).frame(width: 78, height: 78)
                    }
                    .scaleEffect(isCapturing ? 0.9 : 1)
                }
                .buttonStyle(.plain)
                .disabled(isCapturing)
                .accessibilityLabel("拍照")
            }

            Spacer()

            // 占位，保持快门居中
            Color.clear.frame(width: 56, height: 56)
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.bottom, Spacing.lg)

    }

    // MARK: - 不支持实时取景时

    private var fallback: some View {
        VStack(spacing: Spacing.lg) {
            ZStack {
                Text("📸")
                    .font(.system(size: 64))
                    .frame(width: 140, height: 140)
                    .background(Color.white.opacity(0.08), in: .circle)
                WordSticker(word: "menu", gloss: "菜单")
                    .rotationEffect(.degrees(-8))
                    .offset(x: -70, y: 52)
                WordSticker(word: "exit", gloss: "出口")
                    .rotationEffect(.degrees(7))
                    .offset(x: 72, y: -48)
            }
            .environment(\.colorScheme, .light)
            .padding(.bottom, Spacing.sm)

            VStack(spacing: Spacing.xs) {
                Text("选一张有英文的照片")
                    .font(.title2.weight(.heavy))
                Text("菜单、路牌、包装、通知单都可以")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
            }
            VStack(spacing: Spacing.sm) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label("从相册选择", systemImage: "photo.on.rectangle")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color(hex: 0x1C1B20))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color(hex: 0xF6F2EA), in: .capsule)
                }
                .buttonStyle(.pressable)

                if UIImagePickerController.isSourceTypeAvailable(.camera) && !cameraDenied {
                    Button {
                        showingSystemCamera = true
                    } label: {
                        Label("拍照", systemImage: "camera")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.white.opacity(0.12), in: .capsule)
                    }
                    .buttonStyle(.pressable)
                }
            }
            .padding(.horizontal, Spacing.xl)

            if cameraDenied {
                Button("相机权限已关闭，去设置开启") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(0.6))
            }
        }
        .foregroundStyle(.white)
    }

    private func checkCamera() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            cameraDenied = !granted
        case .denied, .restricted:
            cameraDenied = true
        default:
            cameraDenied = false
        }
        cameraChecked = true
    }

    // MARK: - 动作

    private func capture() {
        isCapturing = true
        Task {
            defer { isCapturing = false }
            if let image = await scanner.capture() {
                onCapture(image)
            }
        }
    }

    private func load(_ item: PhotosPickerItem) async {
        defer { photoItem = nil }
        do {
            guard let data = try await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
                loadError = "这张照片无法打开，换一张试试。"
                return
            }
            onCapture(image)
        } catch {
            loadError = "读取照片失败：\(error.localizedDescription)"
        }
    }
}

// MARK: - VisionKit 实时文字取景

@Observable
final class LiveScannerController {
    weak var scanner: DataScannerViewController?
    var recognizedCount = 0

    func capture() async -> UIImage? {
        try? await scanner?.capturePhoto()
    }
}

struct LiveTextScanner: UIViewControllerRepresentable {
    var controller: LiveScannerController

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text(languages: ["en"])],
            qualityLevel: .accurate,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        controller.scanner = scanner
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        // 视图出现在屏幕上之后再开始扫描
        if !uiViewController.isScanning {
            try? uiViewController.startScanning()
        }
    }

    static func dismantleUIViewController(_ uiViewController: DataScannerViewController, coordinator: Coordinator) {
        uiViewController.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(controller: controller) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let controller: LiveScannerController
        init(controller: LiveScannerController) { self.controller = controller }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            controller.recognizedCount = allItems.count
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didRemove removedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            controller.recognizedCount = allItems.count
        }
    }
}

// MARK: - 系统相机（设备不支持实时取景时）

struct SystemCameraPicker: UIViewControllerRepresentable {
    var onFinish: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onFinish: (UIImage?) -> Void
        init(onFinish: @escaping (UIImage?) -> Void) { self.onFinish = onFinish }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onFinish(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onFinish(nil)
        }
    }
}
