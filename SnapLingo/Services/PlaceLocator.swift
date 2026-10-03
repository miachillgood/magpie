//
//  PlaceLocator.swift
//  SnapLingo
//
//  拍照时记下在哪个街区（Ponsonby、Fitzroy……），首页写成「刚刚在 Ponsonby 的 Little Bird 咖啡菜单」。
//  - 只给相机拍的照片定位；相册里的照片可能是在别处拍的，不定位
//  - 权限在第一次拍完照、选词页上问（先说明用来干嘛，用户点了才弹系统授权），拒绝了不影响使用
//  - 位置只存在手机上，不发给 AI，也不上传
//

import CoreLocation
import MapKit

/// 一次拍照的位置
struct ScanPlace: Equatable, Sendable {
    /// 街区名；新西兰是 suburb（Ponsonby），澳洲的 city 本身就是 suburb（Fitzroy）
    var neighborhood: String
    var latitude: Double
    var longitude: Double
}

@MainActor
final class PlaceLocator: NSObject, CLLocationManagerDelegate {
    static let shared = PlaceLocator()

    /// 选词页上的说明卡片问过一次了（不管选了什么都不再问）
    static let askedKey = "locationAsked"

    private let manager = CLLocationManager()
    private var authorizationWaiters: [CheckedContinuation<Void, Never>] = []
    private var locationWaiters: [CheckedContinuation<CLLocation?, Never>] = []

    override private init() {
        super.init()
        manager.delegate = self
        // 街区级别就够了，不用精确到门牌
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var isAuthorized: Bool {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: true
        default: false
        }
    }

    /// 还没问过系统权限、也没在说明卡片上点过「不用了」
    var shouldOffer: Bool {
        manager.authorizationStatus == .notDetermined && !UserDefaults.standard.bool(forKey: Self.askedKey)
    }

    func markAsked() {
        UserDefaults.standard.set(true, forKey: Self.askedKey)
    }

    /// 弹系统授权，等用户选完
    func requestPermission() async -> Bool {
        markAsked()
        guard manager.authorizationStatus == .notDetermined else { return isAuthorized }
        await withCheckedContinuation { continuation in
            authorizationWaiters.append(continuation)
            manager.requestWhenInUseAuthorization()
        }
        return isAuthorized
    }

    /// 现在在哪个街区；没权限、定位失败或 10 秒内没结果都返回 nil
    func currentPlace() async -> ScanPlace? {
        guard isAuthorized, let location = await currentLocation() else { return nil }
        guard let request = MKReverseGeocodingRequest(location: location) else { return nil }
        request.preferredLocale = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en")
        guard let item = try? await request.mapItems.first else { return nil }
        let neighborhood = Self.neighborhood(
            shortAddress: item.address?.shortAddress,
            name: item.name,
            city: item.addressRepresentations?.cityName
        )
        guard let neighborhood else { return nil }
        return ScanPlace(neighborhood: neighborhood, latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
    }

    private func currentLocation() async -> CLLocation? {
        await withCheckedContinuation { continuation in
            locationWaiters.append(continuation)
            manager.requestLocation()
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(10))
                self.finishLocation(nil)
            }
        }
    }

    private func finishLocation(_ location: CLLocation?) {
        let waiters = locationWaiters
        locationWaiters = []
        waiters.forEach { $0.resume(returning: location) }
    }

    /// 从地址里取街区名。MapKit 的 shortAddress 是「门牌, 街区, 城市」（4 Brown St, Ponsonby, Auckland）：
    /// 城市前面那一段、又不是门牌的，就是街区；取不到就用城市名
    nonisolated static func neighborhood(shortAddress: String?, name: String?, city: String?) -> String? {
        let city = city?.trimmingCharacters(in: .whitespaces) ?? ""
        let parts = (shortAddress ?? "")
            .components(separatedBy: CharacterSet(charactersIn: ",，、"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if !city.isEmpty, let cityIndex = parts.firstIndex(where: { $0.hasPrefix(city) }), cityIndex > 0 {
            let candidate = parts[cityIndex - 1]
            let isStreet = candidate == name || candidate.first?.isNumber == true
            if !isStreet { return candidate }
        }
        return city.isEmpty ? nil : city
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            guard manager.authorizationStatus != .notDetermined else { return }
            let waiters = self.authorizationWaiters
            self.authorizationWaiters = []
            waiters.forEach { $0.resume() }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations.last
        Task { @MainActor in self.finishLocation(location) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.finishLocation(nil) }
    }
}
