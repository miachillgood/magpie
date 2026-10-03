//
//  ScanCameraView.swift
//  SnapLingo
//

import AVFoundation
import PhotosUI
import SwiftUI
import VisionKit

/// 取景页：黑底 + 日期 + 取景框 + 底部三个按钮（关闭 / 黄色快门 / 相册）。
/// 支持的设备用 VisionKit 实时高亮文字；不支持时按快门打开系统相机，没有相机就打开相册
struct ScanCameraView: View {
    /// 第二个参数：是不是相机现拍的（相册里选的是 false，不定位）
    var onCapture: (UIImage, _ fromCamera: Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var scanner = LiveScannerController()
    @State private var photoItem: PhotosPickerItem?
    @State private var isCapturing = false
    @State private var showingSystemCamera = false
    @State private var showingPhotoPicker = false
    @State private var loadError: String?
    /// 先确认相机权限再决定是否实时取景（未授权时 isAvailable 为 false）
    @State private var cameraChecked = false
    @State private var cameraDenied = false
    /// 不为 nil 时盖一层相机权限说明页
    @State private var permission: CameraPermissionView.Mode?
    /// 取景页固定深色，说明页跟随系统
    @Environment(\.colorScheme) private var systemScheme
    @Environment(\.scenePhase) private var scenePhase

    private var liveScanAvailable: Bool {
        cameraChecked && DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    private var systemCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera) && !cameraDenied
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if liveScanAvailable {
                LiveTextScanner(controller: scanner)
                    .ignoresSafeArea()
            }
            VStack(spacing: 0) {
                Text(HomeDates.dateText(for: Date()))
                    .font(.system(size: 30, weight: .regular, design: .serif))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 28)
                    .padding(.top, 16)
                    .accessibilityAddTraits(.isHeader)

                Spacer(minLength: 20)
                viewfinder
                Spacer(minLength: 20)

                controls
                    .padding(.bottom, 16)
            }

            if let permission {
                CameraPermissionView(mode: permission) {
                    Task { await requestCamera() }
                } onPickPhoto: {
                    showingPhotoPicker = true
                } onLater: {
                    dismiss()
                }
                .environment(\.colorScheme, systemScheme)
                .transition(.opacity)
            }
        }
        .animation(.smooth, value: permission)
        .task { await checkCamera() }
        .onChange(of: scenePhase) { _, phase in
            // 从设置里打开权限回来
            if phase == .active, permission == .denied { Task { await checkCamera() } }
        }
        .toolbarVisibility(.hidden, for: .navigationBar)
        .environment(\.colorScheme, .dark)
        .sensoryFeedback(.impact(weight: .medium), trigger: isCapturing) { _, new in new }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await load(item) }
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $photoItem, matching: .images)
        .fullScreenCover(isPresented: $showingSystemCamera) {
            SystemCameraPicker { image in
                showingSystemCamera = false
                if let image { onCapture(image, true) }
            }
            .ignoresSafeArea()
        }
        .alert("无法读取照片", isPresented: Binding(get: { loadError != nil }, set: { if !$0 { loadError = nil } })) {
            Button("好", role: .cancel) {}
        } message: {
            Text(loadError ?? "")
        }
    }

    // MARK: - 取景框

    private var viewfinder: some View {
        ViewfinderCorners()
            .stroke(.white, style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
            .aspectRatio(0.8, contentMode: .fit)
            .overlay(alignment: .bottom) {
                VStack(spacing: 10) {
                    Text(hintText)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: scanner.recognizedCount)
                    if cameraDenied && UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button("相机权限已关闭，去设置开启") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 36)
                .padding(.bottom, 30)
            }
            .padding(.horizontal, 52)
    }

    private var hintText: String {
        if liveScanAvailable {
            return scanner.recognizedCount > 0
                ? String(localized: "找到 \(scanner.recognizedCount) 段文字\n按下快门", comment: "Camera hint while live text detection sees text")
                : String(localized: "请把英文放进框里")
        }
        if systemCameraAvailable { return String(localized: "按下快门\n拍一张有英文的照片") }
        return String(localized: "按下快门\n从相册选一张有英文的照片")
    }

    // MARK: - 底部按钮

    private var controls: some View {
        HStack {
            Button { dismiss() } label: {
                circleLabel("xmark")
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("关闭")

            Spacer()

            shutter

            Spacer()

            PhotosPicker(selection: $photoItem, matching: .images) {
                circleLabel("photo")
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("从相册选择")
        }
        .padding(.horizontal, 34)
    }

    private func circleLabel(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 56, height: 56)
            .background(Color.white.opacity(0.12), in: .circle)
    }

    /// 黄色快门（和底部导航同一张图）；黄色色块是偏的，按黑色圆的圆心居中
    private var shutter: some View {
        let width: CGFloat = 118
        let height = width * 778 / 864
        return Button { shutterTapped() } label: {
            Image("TabShutter")
                .resizable()
                .frame(width: width, height: height)
                .offset(x: (0.5 - 0.4711) * width, y: (0.5 - 0.5495) * height)
                .scaleEffect(isCapturing ? 0.9 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isCapturing)
                .frame(width: 84, height: 84)
                .contentShape(.circle)
        }
        .buttonStyle(.pressable)
        .disabled(isCapturing)
        .accessibilityLabel("拍照")
    }

    private func shutterTapped() {
        if liveScanAvailable {
            capture()
        } else if systemCameraAvailable {
            showingSystemCamera = true
        } else {
            showingPhotoPicker = true
        }
    }

    private func checkCamera() async {
        let hasCamera = UIImagePickerController.isSourceTypeAvailable(.camera)
        #if DEBUG
        // 截图用：-cameraPermission ask / denied（模拟器没有相机）
        if let forced = OnboardingDebug.value(after: "-cameraPermission") {
            permission = forced == "denied" ? .denied : .ask
            return
        }
        #endif
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            if hasCamera {
                // 先看说明页，点“允许”再弹系统框
                permission = .ask
                return
            }
            cameraDenied = false
        case .denied, .restricted:
            cameraDenied = true
            permission = hasCamera ? .denied : nil
        default:
            cameraDenied = false
            permission = nil
        }
        cameraChecked = true
    }

    private func requestCamera() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        cameraDenied = !granted
        permission = granted ? nil : .denied
        cameraChecked = true
    }

    // MARK: - 动作

    private func capture() {
        isCapturing = true
        Task {
            defer { isCapturing = false }
            if let image = await scanner.capture() {
                onCapture(image, true)
            }
        }
    }

    private func load(_ item: PhotosPickerItem) async {
        defer { photoItem = nil }
        do {
            guard let data = try await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
                loadError = String(localized: "这张照片无法打开，换一张试试。")
                return
            }
            onCapture(image, false)
        } catch {
            loadError = String(localized: "读取照片失败：\(error.localizedDescription)")
        }
    }
}

// MARK: - 取景框

/// 四个圆角的取景框角
struct ViewfinderCorners: Shape {
    var length: CGFloat = 38
    var radius: CGFloat = 20

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + length))
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.minX + length, y: rect.minY), radius: radius)
        path.addLine(to: CGPoint(x: rect.minX + length, y: rect.minY))

        path.move(to: CGPoint(x: rect.maxX - length, y: rect.minY))
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.minY + length), radius: radius)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + length))

        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - length))
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.maxX - length, y: rect.maxY), radius: radius)
        path.addLine(to: CGPoint(x: rect.maxX - length, y: rect.maxY))

        path.move(to: CGPoint(x: rect.minX + length, y: rect.maxY))
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.maxY - length), radius: radius)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - length))
        return path
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
