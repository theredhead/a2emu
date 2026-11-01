import Foundation

private let playerManifestIntl = PlayerManifestIntl()

/// Resolves the current application display name without coupling persisted profile rules to Bundle.main.
extension PlayerManifest {
    static var displayName: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? playerManifestIntl.appleIiPlayer
    }
}
