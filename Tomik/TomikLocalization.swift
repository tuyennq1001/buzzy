import Foundation
import SwiftUI

public enum TomikLanguage: String, CaseIterable, Identifiable {
    case vi = "vi"
    case en = "en"
    case ja = "ja"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .vi: return "Tiếng Việt"
        case .en: return "English"
        case .ja: return "日本語"
        }
    }

    public var flag: String {
        switch self {
        case .vi: return "🇻🇳"
        case .en: return "🇬🇧"
        case .ja: return "🇯🇵"
        }
    }
}

public class TomikLocalization: ObservableObject {
    public static let shared = TomikLocalization()

    @AppStorage("appLanguage") public var currentLanguageRaw: String = "vi" {
        didSet {
            loadBundle()
            objectWillChange.send()
        }
    }

    public var currentLanguage: TomikLanguage {
        get { TomikLanguage(rawValue: currentLanguageRaw) ?? .vi }
        set { currentLanguageRaw = newValue.rawValue }
    }

    private var bundle: Bundle = .main

    private init() {
        loadBundle()
    }

    private func loadBundle() {
        let lang = UserDefaults.standard.string(forKey: "appLanguage") ?? "vi"
        if let path = Bundle.main.path(forResource: lang, ofType: "lproj"),
           let b = Bundle(path: path) {
            bundle = b
        } else {
            bundle = .main
        }
    }

    public func tr(_ key: String) -> String {
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    public func tr(_ key: String, value: String) -> String {
        return bundle.localizedString(forKey: key, value: value, table: nil)
    }

    public func tr(_ key: String, _ args: CVarArg...) -> String {
        let format = bundle.localizedString(forKey: key, value: key, table: nil)
        return String(format: format, arguments: args)
    }
}

public enum TomikSoundTheme: String, CaseIterable, Identifiable {
    case ding = "ding"
    case cat = "cat"
    case duck = "duck"
    case bird = "bird"
    case puppy = "puppy"

    public var id: String { rawValue }

    public var assetName: String {
        switch self {
        case .ding: return "ding"
        case .cat: return "sound_cat"
        case .duck: return "sound_duck"
        case .bird: return "sound_bird"
        case .puppy: return "sound_puppy"
        }
    }

    public var icon: String {
        switch self {
        case .ding: return "🔔"
        case .cat: return "🐱"
        case .duck: return "🦆"
        case .bird: return "🐦"
        case .puppy: return "🐶"
        }
    }

    public func displayName(for language: TomikLanguage) -> String {
        switch language {
        case .vi:
            switch self {
            case .ding: return "Chuông Ding"
            case .cat: return "Mèo con (Meow)"
            case .duck: return "Vịt con (Cạp cạp)"
            case .bird: return "Chim hót"
            case .puppy: return "Chó con"
            }
        case .en:
            switch self {
            case .ding: return "Classic Bell"
            case .cat: return "Cute Kitten"
            case .duck: return "Cute Duck (Quack)"
            case .bird: return "Bird Song"
            case .puppy: return "Happy Puppy"
            }
        case .ja:
            switch self {
            case .ding: return "クラシックベル"
            case .cat: return "子猫の鳴き声"
            case .duck: return "アヒル (ガーガー)"
            case .bird: return "小鳥のさえずり"
            case .puppy: return "子犬の鳴き声"
            }
        }
    }
}
