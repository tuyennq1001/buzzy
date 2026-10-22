import AppKit
import Foundation

#if !APP_STORE
import Sparkle

@MainActor
private final class BuzzySparkleUserDriver: SPUStandardUserDriver {
    weak var viewModel: BuzzyUpdaterViewModel?
    private var readyToInstallReply: ((SPUUserUpdateChoice) -> Void)?
    private var installWhenReady = false

    override func showUpdateFound(with appcastItem: SUAppcastItem, state: SPUUserUpdateState, reply: @escaping (SPUUserUpdateChoice) -> Void) {
        if installWhenReady, state.stage == .downloaded {
            reply(.install)
        } else {
            super.showUpdateFound(with: appcastItem, state: state, reply: reply)
        }
    }

    @objc(showReadyToInstallAndRelaunch:)
    func showReadyToInstallAndRelaunch(_ reply: @escaping (SPUUserUpdateChoice) -> Void) {
        if installWhenReady {
            installWhenReady = false
            viewModel?.setUpdateReady(false)
            reply(.install)
            return
        }

        readyToInstallReply = reply
        viewModel?.setUpdateReady(true)

        let alert = NSAlert()
        alert.messageText = BuzzyLocalization.shared.tr("Updater.ready.title", value: "Update ready to install")
        alert.informativeText = BuzzyLocalization.shared.tr("Updater.ready.message", value: "Restart now to finish updating Buzzy, or do it later from the menu bar popover.")
        alert.addButton(withTitle: BuzzyLocalization.shared.tr("Updater.ready.later", value: "Later"))
        alert.addButton(withTitle: BuzzyLocalization.shared.tr("Updater.ready.restart", value: "Restart & Install"))
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertSecondButtonReturn {
            installReadyUpdate()
        } else {
            deferReadyUpdate()
        }
    }

    func installReadyUpdate() {
        if let reply = readyToInstallReply {
            readyToInstallReply = nil
            viewModel?.setUpdateReady(false)
            reply(.install)
            return
        }

        guard let viewModel else { return }
        installWhenReady = true
        viewModel.checkForUpdates()
    }

    func deferReadyUpdate() {
        guard let reply = readyToInstallReply else { return }
        readyToInstallReply = nil
        reply(.dismiss)
        viewModel?.setUpdateReady(true)
        // Clear Sparkle's non-closable ready window after deferring; the cached update is kept.
        super.showUpdateInstalledAndRelaunched(true, acknowledgement: {})
    }
}

final class BuzzySparkleDelegate: NSObject, SPUUpdaterDelegate {
    func updater(_ updater: SPUUpdater, didFinishLoading appcast: SUAppcast) {
        NSLog("[Sparkle] Appcast loaded successfully with %d item(s)", appcast.items.count)
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        NSLog("[Sparkle] Update aborted: %@", error.localizedDescription)
    }
}
#endif

@MainActor
public final class BuzzyUpdaterViewModel: ObservableObject {
    public static let shared = BuzzyUpdaterViewModel()

    #if !APP_STORE
    private var updater: SPUUpdater?
    private var userDriver: BuzzySparkleUserDriver?
    private let sparkleDelegate = BuzzySparkleDelegate()
    #endif

    @Published public private(set) var canCheckForUpdates: Bool = false
    @Published public private(set) var isUpdateReady: Bool = false
    @Published public var automaticallyDownloadsUpdates: Bool = true {
        didSet {
            #if !APP_STORE
            updater?.automaticallyDownloadsUpdates = automaticallyDownloadsUpdates
            #endif
        }
    }

    public var isAvailable: Bool {
        #if APP_STORE
        return false
        #else
        return updater != nil
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
            let userDriver = BuzzySparkleUserDriver(hostBundle: .main, delegate: nil)
            let updater = SPUUpdater(
                hostBundle: .main,
                applicationBundle: .main,
                userDriver: userDriver,
                delegate: sparkleDelegate
            )
            userDriver.viewModel = self
            self.userDriver = userDriver
            self.updater = updater
            do {
                try updater.start()
                self.canCheckForUpdates = updater.canCheckForUpdates
                self.automaticallyDownloadsUpdates = updater.automaticallyDownloadsUpdates
            } catch {
                NSLog("[Sparkle] Failed to start updater: %@", error.localizedDescription)
                self.canCheckForUpdates = false
            }
        } else {
            self.updater = nil
            self.userDriver = nil
            self.canCheckForUpdates = false
        }
        #endif
    }

    public func checkForUpdates() {
        #if !APP_STORE
        guard let updater = updater else {
            NSLog("[Sparkle] Updater controller is not active in this environment.")
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        updater.checkForUpdates()
        #endif
    }

    public func restartAndInstallUpdate() {
        #if !APP_STORE
        userDriver?.installReadyUpdate()
        #endif
    }

    fileprivate func setUpdateReady(_ isReady: Bool) {
        isUpdateReady = isReady
    }
}
