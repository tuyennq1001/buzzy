import AppKit
import Foundation

#if !APP_STORE
import Sparkle

final class BuzzySparkleDelegate: NSObject, SPUUpdaterDelegate {
    func updater(_ updater: SPUUpdater, didFinishLoading appcast: SUAppcast) {
        NSLog("[Sparkle] Appcast loaded successfully with %d item(s)", appcast.items.count)
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        NSLog("[Sparkle] Update aborted: %@", error.localizedDescription)
    }
}
#endif

public final class BuzzyUpdaterViewModel: ObservableObject {
    public static let shared = BuzzyUpdaterViewModel()

    #if !APP_STORE
    private var controller: SPUStandardUpdaterController?
    private let sparkleDelegate = BuzzySparkleDelegate()
    #endif

    @Published public private(set) var canCheckForUpdates: Bool = false
    @Published public var automaticallyDownloadsUpdates: Bool = true {
        didSet {
            #if !APP_STORE
            controller?.updater.automaticallyDownloadsUpdates = automaticallyDownloadsUpdates
            #endif
        }
    }

    public var isAvailable: Bool {
        #if APP_STORE
        return false
        #else
        return controller != nil
        #endif
    }

    public var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(buzzyAppTitle) v\(version) (\(build))"
    }

    private init() {
        #if APP_STORE
        self.canCheckForUpdates = false
        #else
        let bundleId = Bundle.main.bundleIdentifier ?? ""
        let feedURL = Bundle.main.infoDictionary?["SUFeedURL"] as? String ?? ""

        #if DEBUG
        // In local debug development (Buzzy Dev), keep updater inactive to prevent accidental overwrites
        let isDev = true
        #else
        let isDev = bundleId.contains(".dev")
        #endif

        if !isDev && !feedURL.isEmpty {
            let updaterController = SPUStandardUpdaterController(
                startingUpdater: true,
                updaterDelegate: sparkleDelegate,
                userDriverDelegate: nil
            )
            self.controller = updaterController
            self.canCheckForUpdates = updaterController.updater.canCheckForUpdates
            self.automaticallyDownloadsUpdates = updaterController.updater.automaticallyDownloadsUpdates
        } else {
            self.controller = nil
            self.canCheckForUpdates = false
        }
        #endif
    }

    public func checkForUpdates() {
        #if !APP_STORE
        guard let controller = controller else {
            NSLog("[Sparkle] Updater controller is not active in this environment.")
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        controller.updater.checkForUpdates()
        #endif
    }
}
