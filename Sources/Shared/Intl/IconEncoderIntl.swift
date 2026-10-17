import Foundation

/// Localized text for IconEncoder; resource lookup and formatting stay out of the UI code.
final class IconEncoderIntl {
    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    var couldNotEncodeIcon: String {
        NSLocalizedString(
            "couldNotEncodeIcon", tableName: "IconEncoder", bundle: bundle, value: "Could not encode icon.",
            comment: "IconEncoder: User-visible label, instruction, or error message.")
    }

    var theIconImageIsInvalid: String {
        NSLocalizedString(
            "theIconImageIsInvalid", tableName: "IconEncoder", bundle: bundle,
            value: "The icon image is invalid.",
            comment: "IconEncoder: User-visible label, instruction, or error message.")
    }
}
