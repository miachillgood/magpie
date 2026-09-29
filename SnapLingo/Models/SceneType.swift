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
        case .restaurant:  "餐厅"
        case .supermarket: "超市"
        case .shopping:    "购物"
        case .housing:     "租房"
        case .campus:      "校园"
        case .medical:     "医疗"
        case .transport:   "交通"
        case .bank:        "银行"
        case .legal:       "文件"
        case .signage:     "标识"
        case .general:     "日常"
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

    /// 写给 Claude 的判定说明
    var promptHint: String {
        switch self {
        case .restaurant:  "菜单、咖啡单、外卖单、饮品单"
        case .supermarket: "食品包装、货架标签、成分表、营养成分、超市促销"
        case .shopping:    "商店标签、衣物洗涤标、退换货政策、电子产品包装"
        case .housing:     "租房广告、租约、房屋检查单、水电账单、公寓通知"
        case .campus:      "课程表、作业要求、图书馆、学校通知、学生卡"
        case .medical:     "药品说明、处方、诊所单据、保健品、疫苗、医疗保险"
        case .transport:   "公交/火车时刻表、车票、停车标志、机场指引"
        case .bank:        "银行卡、账单、转账单、税务信件"
        case .legal:       "合同、条款、政府文件、法律声明、签证材料"
        case .signage:     "路牌、公告、警示标语、营业时间、指示牌"
        case .general:     "以上都不符合时"
        }
    }

    init(key: String) {
        self = SceneType(rawValue: key.lowercased().trimmingCharacters(in: .whitespaces)) ?? .general
    }
}
