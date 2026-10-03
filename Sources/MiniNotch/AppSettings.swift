import CoreGraphics
import Foundation
import Observation

/// User preferences shown in the context menu, persisted in UserDefaults.
@MainActor
@Observable
final class AppSettings {
    enum HoverDelay: String, CaseIterable, Identifiable {
        case off, short, long

        var id: Self { self }
        var title: String {
            switch self {
            case .off: "Off"
            case .short: "Short"
            case .long: "Long"
            }
        }
        var duration: Duration {
            switch self {
            case .off: .zero
            case .short: .milliseconds(150)
            case .long: .milliseconds(350)
            }
        }
    }

    enum IslandSize: String, CaseIterable, Identifiable {
        case small, medium, large

        var id: Self { self }
        var title: String {
            switch self {
            case .small: "Small"
            case .medium: "Medium"
            case .large: "Large"
            }
        }
        var width: CGFloat {
            switch self {
            case .small: 90
            case .medium: 110
            case .large: 150
            }
        }
    }

    private enum Key {
        static let hoverDelay = "hoverDelay"
        static let islandSize = "islandSize"
    }

    var hoverDelay: HoverDelay {
        didSet { defaults.set(hoverDelay.rawValue, forKey: Key.hoverDelay) }
    }

    var islandSize: IslandSize {
        didSet {
            defaults.set(islandSize.rawValue, forKey: Key.islandSize)
            onIslandSizeChange?()
        }
    }

    /// Island geometry lives in the window controllers, so they must re-layout.
    @ObservationIgnored var onIslandSizeChange: (() -> Void)?
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hoverDelay = defaults.string(forKey: Key.hoverDelay).flatMap(HoverDelay.init) ?? .off
        islandSize = defaults.string(forKey: Key.islandSize).flatMap(IslandSize.init) ?? .medium
    }
}
