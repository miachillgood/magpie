//
//  UserProfile.swift
//  SnapLingo
//

import Foundation
import SwiftData

@Model
final class UserProfile {
    @Attribute(.unique) var appleUserID: String
    var displayName: String
    var email: String?
    var createdAt: Date
    var lastSignedInAt: Date

    init(appleUserID: String, displayName: String, email: String? = nil) {
        self.appleUserID = appleUserID
        self.displayName = displayName
        self.email = email
        self.createdAt = Date()
        self.lastSignedInAt = Date()
    }
}
