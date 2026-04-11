import Combine
import Foundation
import SwiftUI

final class AppVisibilityStore: ObservableObject {
    static let shared = AppVisibilityStore()

    private static let showsDockIconKey = "showsDockIcon"

    @Published var showsDockIcon: Bool {
        didSet {
            UserDefaults.standard.set(showsDockIcon, forKey: Self.showsDockIconKey)
        }
    }

    private init() {
        showsDockIcon = UserDefaults.standard.bool(forKey: Self.showsDockIconKey)
    }
}
