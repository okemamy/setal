import AppKit

enum Links {
    /// Lien de don PayPal (par ex. "https://paypal.me/pseudo").
    /// Tant qu'il est vide, les boutons de don sont masqués.
    /// À garder identique à `.github/FUNDING.yml`.
    static let donateURLString = "https://paypal.me/sybirante"

    static var donate: URL? {
        donateURLString.isEmpty ? nil : URL(string: donateURLString)
    }

    static func openDonate() {
        if let donate { NSWorkspace.shared.open(donate) }
    }
}
