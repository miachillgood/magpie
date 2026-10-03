//
//  SceneType.swift
//  SnapLingo
//

import Foundation

/// 照片的自动分类（12 类），按“在哪儿看到这段英文”来分，拍完由 Claude 选一类，用户可以改。
/// raw value 是给 Claude 的英文 key，也是数据库里存的值；旧版本的 supermarket / legal 读出来时并进购物 / 钱和办事
enum SceneType: String, Codable, CaseIterable, Identifiable, Sendable {
    case restaurant
    case shopping
    case transport
    case signage
    case housing
    case campus
    case medical
    case bank
    case sports
    case leisure
    case tech
    case general

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .restaurant: String(localized: "吃喝", comment: "Photo category: menus, cafés, food packaging")
        case .shopping:   String(localized: "购物", comment: "Photo category: supermarkets, price tags, shops, clothes")
        case .transport:  String(localized: "出行旅行", comment: "Photo category: buses, trains, airports, parking, hotels, sights")
        case .signage:    String(localized: "标识告示", comment: "Photo category: street signs, warnings, notices")
        case .housing:    String(localized: "住家", comment: "Photo category: renting, home appliances, bills, mail")
        case .campus:     String(localized: "工作学习", comment: "Photo category: office, school, textbooks, forms")
        case .medical:    String(localized: "医疗健康", comment: "Photo category: pharmacy, clinic, medicine")
        case .bank:       String(localized: "钱和办事", comment: "Photo category: bank, bills, government forms, insurance, post office")
        case .sports:     String(localized: "运动户外", comment: "Photo category: gym, park, hiking, beach")
        case .leisure:    String(localized: "休闲娱乐", comment: "Photo category: cinema, museum, shows, events")
        case .tech:       String(localized: "数码屏幕", comment: "Photo category: app screenshots, device settings, manuals")
        case .general:    String(localized: "其他", comment: "Photo category: anything else")
        }
    }

    /// 分类图标（Assets 里 Icons 文件夹的图）
    var iconName: String {
        switch self {
        case .restaurant: "icon-coffee"
        case .shopping:   "icon-bag"
        case .transport:  "icon-bus"
        case .signage:    "icon-signpost"
        case .housing:    "icon-house"
        case .campus:     "icon-laptop"
        case .medical:    "icon-hospital"
        case .bank:       "icon-card"
        case .sports:     "icon-trees"
        case .leisure:    "icon-masks"
        case .tech:       "icon-phone"
        case .general:    "icon-pin"
        }
    }

    /// 写给 Claude 的分类名（英文，只给模型看）
    var promptName: String {
        switch self {
        case .restaurant: "food and drinks"
        case .shopping:   "shopping"
        case .transport:  "transport and travel"
        case .signage:    "signs and notices"
        case .housing:    "home and housing"
        case .campus:     "work and study"
        case .medical:    "health"
        case .bank:       "money and admin"
        case .sports:     "sports and outdoors"
        case .leisure:    "fun and culture"
        case .tech:       "tech and screens"
        case .general:    "everyday"
        }
    }

    /// 写给 Claude 的判定说明（英文，只给模型看）
    var promptHint: String {
        switch self {
        case .restaurant: "menus, cafés, drink lists, takeaway, food packaging, ingredient and nutrition labels"
        case .shopping:   "supermarket shelves and promotions, price tags, store signs, receipts, clothing labels, return policies"
        case .transport:  "bus/train timetables, tickets, stations, airports, parking, hotels, tourist attractions"
        case .signage:    "street signs, warning signs, notices on doors or walls, opening hours, directions"
        case .housing:    "rental listings, tenancy agreements, home appliances, utility bills, letters, building notices"
        case .campus:     "office documents, timetables, assignments, textbooks, school or workplace notices, forms"
        case .medical:    "pharmacies, medicine leaflets, prescriptions, clinic forms, supplements, health insurance"
        case .bank:       "bank cards and statements, bills, tax letters, government forms, visas, insurance, post office"
        case .sports:     "gyms, sports, parks, hiking tracks, beaches, outdoor safety signs"
        case .leisure:    "cinemas, museums, shows, concerts, events, games, galleries"
        case .tech:       "phone or app screenshots, device settings, error messages, product manuals"
        case .general:    "when nothing above fits"
        }
    }

    /// 读 Claude 的返回值或数据库里存的值；旧版本的分类并进新的
    init(key: String) {
        let key = key.lowercased().trimmingCharacters(in: .whitespaces)
        switch key {
        case "supermarket": self = .shopping
        case "legal":       self = .bank
        default:            self = SceneType(rawValue: key) ?? .general
        }
    }
}
