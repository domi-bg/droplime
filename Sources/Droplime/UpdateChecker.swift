import Foundation

/// Asks GitHub for the latest release. Only ever called when the user chooses "Check for Updates".
enum UpdateChecker {
    enum Result: Equatable {
        case upToDate(version: String)
        case available(version: String, url: URL)
        case failed(message: String)
    }

    static let latestReleaseURL = URL(string: "https://api.github.com/repos/domi-bg/droplime/releases/latest")!

    /// Compares dotted numeric versions ("1.2.3", a leading "v" is ignored; missing parts count as 0).
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let a = components(candidate), b = components(current)
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0, y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    private static func components(_ version: String) -> [Int] {
        let trimmed = version.hasPrefix("v") || version.hasPrefix("V") ? String(version.dropFirst()) : version
        return trimmed.split(separator: ".").map { Int($0.prefix(while: \.isNumber)) ?? 0 }
    }

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    static func check() async -> Result {
        var request = URLRequest(url: latestReleaseURL, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let status = (response as? HTTPURLResponse)?.statusCode, status != 200 {
                return .failed(message: L.updateHTTPError(status))
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = json["tag_name"] as? String,
                  let page = (json["html_url"] as? String).flatMap(URL.init(string:))
            else { return .failed(message: L.updateBadResponse) }
            let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            return isNewer(tag, than: currentVersion) ? .available(version: version, url: page)
                                                      : .upToDate(version: currentVersion)
        } catch {
            return .failed(message: error.localizedDescription)
        }
    }
}
