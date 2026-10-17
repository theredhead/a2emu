import Foundation

/// Localized text for ROMSetup; resource lookup and formatting stay out of the UI code.
final class ROMSetupIntl {
    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    var chooseAComplete128KbRom: String {
        NSLocalizedString(
            "chooseAComplete128KbRom", tableName: "ROMSetup", bundle: bundle,
            value:
                "Choose a complete 128 KB ROM 01 or 256 KB ROM 03 image. Individual ROM chips and ZIP files are not complete ROM images.",
            comment: "ROMSetup: User-visible label, instruction, or error message.")
    }

    var chooseAnAppleIigsRom: String {
        NSLocalizedString(
            "chooseAnAppleIigsRom", tableName: "ROMSetup", bundle: bundle, value: "Choose an Apple IIgs ROM",
            comment: "ROMSetup: User-visible label, instruction, or error message.")
    }

    var couldNotInstallRom: String {
        NSLocalizedString(
            "couldNotInstallRom", tableName: "ROMSetup", bundle: bundle, value: "Could not install ROM",
            comment: "ROMSetup: User-visible label, instruction, or error message.")
    }

    var downloadingRom: String {
        NSLocalizedString(
            "downloadingRom", tableName: "ROMSetup", bundle: bundle, value: "Downloading ROM…",
            comment: "ROMSetup: User-visible label, instruction, or error message.")
    }

    func installedRom(model: String, identifier: String) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString(
                "installedRom", tableName: "ROMSetup", bundle: bundle, value: "Installed ROM %1$@ — %2$@",
                comment:
                    "ROMSetup: Formatted message. model: runtime text; keep its placeholder; identifier: runtime text; keep its placeholder"
            ),
            model, identifier)
    }

    var noAppleIigsRomIsBundled: String {
        NSLocalizedString(
            "noAppleIigsRomIsBundled", tableName: "ROMSetup", bundle: bundle,
            value:
                "No Apple IIgs ROM is bundled with this app. Choose a ROM to download, or browse for your own file. Installed ROMs are shared with your other a2emu players, so you only need to install them once. Each player keeps its own ROM choice. Changing this player’s ROM restarts the emulator.",
            comment: "ROMSetup: User-visible label, instruction, or error message.")
    }

    var recommendedROM: String {
        NSLocalizedString(
            "recommendedROM", tableName: "ROMSetup", bundle: bundle, value: "ROM 03 (recommended)",
            comment: "ROMSetup: User-visible label, instruction, or error message.")
    }

    var rom01: String {
        NSLocalizedString(
            "rom01", tableName: "ROMSetup", bundle: bundle, value: "ROM 01",
            comment: "ROMSetup: User-visible label, instruction, or error message.")
    }

    var setUpYourAppleIigsRom: String {
        NSLocalizedString(
            "setUpYourAppleIigsRom", tableName: "ROMSetup", bundle: bundle,
            value: "Set up your Apple IIgs ROM",
            comment: "ROMSetup: User-visible label, instruction, or error message.")
    }

    var theDownloadCouldNotBeVerified: String {
        NSLocalizedString(
            "theDownloadCouldNotBeVerified", tableName: "ROMSetup", bundle: bundle,
            value: "The download could not be verified. Try again or browse for your own ROM.",
            comment: "ROMSetup: User-visible label, instruction, or error message.")
    }

    var thisImageDoesNotContainA: String {
        NSLocalizedString(
            "thisImageDoesNotContainA", tableName: "ROMSetup", bundle: bundle,
            value:
                "This image does not contain a recognized Apple IIgs reset vector. Please choose a different ROM.",
            comment: "ROMSetup: User-visible label, instruction, or error message.")
    }

    var useSelectedRom: String {
        NSLocalizedString(
            "useSelectedRom", tableName: "ROMSetup", bundle: bundle, value: "Use Selected ROM",
            comment: "ROMSetup: User-visible label, instruction, or error message.")
    }

    var downloadVerificationHint: String {
        NSLocalizedString(
            "downloadVerificationHint", tableName: "ROMSetup", bundle: bundle,
            value: "Downloading from mirrors.apple2.org.za and verifying the image.",
            comment: "Progress text. Keep the download server hostname unchanged.")
    }
}
