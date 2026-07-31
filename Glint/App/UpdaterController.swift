import Combine
import Sparkle
import SwiftUI

/// SwiftUI-friendly wrapper around `SPUStandardUpdaterController`.
///
/// The feed URL and public EdDSA key are read from Info.plist (`SUFeedURL`,
/// `SUPublicEDKey`). Toggling `automaticallyChecksForUpdates` and
/// `checkForUpdates` are forwarded straight to Sparkle's updater so SwiftUI
/// controls stay in lockstep with the framework's own state.
@MainActor
final class UpdaterController: NSObject, ObservableObject {
    private var controller: SPUStandardUpdaterController!

    /// UserDefaults key backing the beta opt-in. Read directly in the
    /// (nonisolated) Sparkle delegate callback, so it lives outside the
    /// published property.
    nonisolated private static let receiveBetaUpdatesKey = "GlintReceiveBetaUpdates"

    /// Bound to the "Check for updates automatically" toggle in Settings.
    @Published var automaticallyChecksForUpdates: Bool = false {
        didSet {
            guard let controller,
                  controller.updater.automaticallyChecksForUpdates != automaticallyChecksForUpdates else { return }
            controller.updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates
        }
    }

    /// Bound to the "Check now" button label so it can disable while a
    /// check is in flight (Sparkle exposes this on the updater).
    @Published var canCheckForUpdates: Bool = true

    /// Bound to the "Receive beta updates" toggle in Settings. Opting in
    /// makes Sparkle consider appcast items tagged <sparkle:channel>beta;
    /// stable-only users never see them.
    @Published var receiveBetaUpdates: Bool {
        didSet {
            UserDefaults.standard.set(receiveBetaUpdates, forKey: Self.receiveBetaUpdatesKey)
        }
    }

    private var cancellables: Set<AnyCancellable> = []

    /// The fork uses a distinct app identity and is updated by its local build
    /// lane, not the upstream Sparkle feed or its EdDSA key.
    var updatesManagedLocally: Bool {
        #if CTRIXIN_DISTRIBUTION
        true
        #else
        false
        #endif
    }

    override init() {
        receiveBetaUpdates = UserDefaults.standard.bool(forKey: Self.receiveBetaUpdatesKey)
        super.init()
        #if DEBUG || CTRIXIN_DISTRIBUTION
        // Debug and the local fork do not consume the upstream appcast. A
        // mismatch here could replace the separately signed local app.
        canCheckForUpdates = false
        #endif
    }

    func startDeferred() {
        #if DEBUG || CTRIXIN_DISTRIBUTION
        canCheckForUpdates = false
        #else
        guard controller == nil else { return }
        DispatchQueue.main.async { [weak self] in
            self?.startIfNeeded()
        }
        #endif
    }

    private func startIfNeeded() {
        #if !DEBUG && !CTRIXIN_DISTRIBUTION
        guard controller == nil else { return }
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
        automaticallyChecksForUpdates = controller.updater.automaticallyChecksForUpdates

        controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .assign(to: &$canCheckForUpdates)
        #endif
    }

    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }
}

extension UpdaterController: SPUUpdaterDelegate {
    /// Sparkle may call this off the main thread; read the preference
    /// straight from UserDefaults (thread-safe) rather than touching
    /// main-actor published state.
    nonisolated func allowedChannels(for updater: SPUUpdater) -> Set<String> {
        UserDefaults.standard.bool(forKey: Self.receiveBetaUpdatesKey) ? ["beta"] : []
    }
}
