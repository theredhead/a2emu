import Foundation

/// Localized text for About; resource lookup and formatting stay out of the UI code.
final class AboutIntl {
    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    var a2emuSourceOnGithub: String {
        NSLocalizedString(
            "a2emuSourceOnGithub", tableName: "About", bundle: bundle, value: "a2emu source on GitHub",
            comment: "About: User-visible label, instruction, or error message.")
    }

    var appleIigsEmulationByKentDickey: String {
        NSLocalizedString(
            "appleIigsEmulationByKentDickey", tableName: "About", bundle: bundle,
            value: "Apple IIgs emulation by Kent Dickey.",
            comment: "About: User-visible label, instruction, or error message.")
    }

    var appleIigsPlayerBuilderAndApple: String {
        NSLocalizedString(
            "appleIigsPlayerBuilderAndApple", tableName: "About", bundle: bundle,
            value: "Apple IIGS Player Builder and Apple II Player",
            comment: "About: User-visible label, instruction, or error message.")
    }

    var crossPlatformWorkByDagenBrock: String {
        NSLocalizedString(
            "crossPlatformWorkByDagenBrock", tableName: "About", bundle: bundle,
            value: "Cross-platform work by Dagen Brock and GSplus contributors, building on KEGS.",
            comment: "About: User-visible label, instruction, or error message.")
    }

    var gsplusSourceOnGithub: String {
        NSLocalizedString(
            "gsplusSourceOnGithub", tableName: "About", bundle: bundle, value: "GSplus source on GitHub",
            comment: "About: User-visible label, instruction, or error message.")
    }

    var kegsProjectAndSource: String {
        NSLocalizedString(
            "kegsProjectAndSource", tableName: "About", bundle: bundle, value: "KEGS project and source",
            comment: "About: User-visible label, instruction, or error message.")
    }

    var license: String {
        NSLocalizedString(
            "license", tableName: "About", bundle: bundle, value: "License",
            comment: "About: User-visible label, instruction, or error message.")
    }

    var more: String {
        NSLocalizedString(
            "more", tableName: "About", bundle: bundle, value: "More…",
            comment: "About: User-visible label, instruction, or error message.")
    }

    var integrationCredit: String {
        NSLocalizedString(
            "integrationCredit", tableName: "About", bundle: bundle,
            value:
                "Swift builder and player integration by theredhead. The builder and player project is available on GitHub.",
            comment: "About: User-visible label, instruction, or error message.")
    }

    var thanksTo: String {
        NSLocalizedString(
            "thanksTo", tableName: "About", bundle: bundle, value: "Thanks to…",
            comment: "About: User-visible label, instruction, or error message.")
    }

    var licenseExplanation: String {
        NSLocalizedString(
            "licenseExplanation", tableName: "About", bundle: bundle,
            value:
                "The builder, player and emulator components are distributed under GNU GPL version 3. Original copyright notices and component licenses are preserved in the project sources. ROM firmware and software you run are separate from the player.",
            comment: "About: User-visible label, instruction, or error message.")
    }

    func versionInfo(version: String) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString(
                "versionInfo", tableName: "About", bundle: bundle,
                value: "Version %1$@\n\nBuilt with KEGS and GSplus.",
                comment: "About: Formatted message. version: runtime text; keep its placeholder"),
            version)
    }

    var viewOnGithub: String {
        NSLocalizedString(
            "viewOnGithub", tableName: "About", bundle: bundle, value: "View on GitHub…",
            comment: "About: User-visible label, instruction, or error message.")
    }
}
