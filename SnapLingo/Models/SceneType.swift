//
//  SceneType.swift
//  SnapLingo
//

import Foundation

/// 场景类型。raw value 使用英文 key，与 Claude 返回值保持一致
enum SceneType: String, Codable, CaseIterable, Identifiable, Sendable {
    case restaurant
    case supermarket
    case shopping
    case housing
    case campus
    case medical
    case transport
    case bank
    case legal
    case signage
    case general

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .restaurant:  String(localized: "餐厅", comment: "Scene type name (short)")
        case .supermarket: String(localized: "超市", comment: "Scene type name (short)")
        case .shopping:    String(localized: "购物", comment: "Scene type name (short)")
        case .housing:     String(localized: "租房", comment: "Scene type name (short)")
        case .campus:      String(localized: "校园", comment: "Scene type name (short)")
        case .medical:     String(localized: "医疗", comment: "Scene type name (short)")
        case .transport:   String(localized: "交通", comment: "Scene type name (short)")
        case .bank:        String(localized: "银行", comment: "Scene type name (short)")
        case .legal:       String(localized: "文件", comment: "Scene type name (short)")
        case .signage:     String(localized: "标识", comment: "Scene type name (short)")
        case .general:     String(localized: "日常", comment: "Scene type name (short)")
        }
    }

    var symbol: String {
        switch self {
        case .restaurant:  "fork.knife"
        case .supermarket: "cart"
        case .shopping:    "bag"
        case .housing:     "house"
        case .campus:      "graduationcap"
        case .medical:     "cross.case"
        case .transport:   "bus"
        case .bank:        "creditcard"
        case .legal:       "doc.text"
        case .signage:     "signpost.right"
        case .general:     "text.viewfinder"
        }
    }

    /// 写给 Claude 的场景名（英文，只给模型看）
    var promptName: String {
        switch self {
        case .restaurant:  "restaurant or café"
        case .supermarket: "supermarket"
        case .shopping:    "shopping"
        case .housing:     "housing and renting"
        case .campus:      "campus"
        case .medical:     "medical"
        case .transport:   "transport"
        case .bank:        "banking and tax"
        case .legal:       "legal and government"
        case .signage:     "public signs"
        case .general:     "everyday"
        }
    }

    /// 写给 Claude 的判定说明（英文，只给模型看）
    var promptHint: String {
        switch self {
        case .restaurant:  "menus, coffee menus, takeaway receipts, drink lists"
        case .supermarket: "food packaging, shelf labels, ingredient lists, nutrition facts, supermarket promotions"
        case .shopping:    "store tags, clothing care labels, return policies, electronics packaging"
        case .housing:     "rental listings, tenancy agreements, property inspection sheets, utility bills, building notices"
        case .campus:      "timetables, assignment briefs, library, school notices, student cards"
        case .medical:     "medicine leaflets, prescriptions, clinic forms, supplements, vaccines, health insurance"
        case .transport:   "bus/train timetables, tickets, parking signs, airport directions"
        case .bank:        "bank cards, statements, transfer forms, tax letters"
        case .legal:       "contracts, terms, government documents, legal notices, visa paperwork"
        case .signage:     "street signs, notices, warning signs, opening hours, directions"
        case .general:     "when nothing above fits"
        }
    }

    init(key: String) {
        self = SceneType(rawValue: key.lowercased().trimmingCharacters(in: .whitespaces)) ?? .general
    }
}
