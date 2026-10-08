import Foundation
import CryptoKit

/// Mengelola pembuatan authentication cookie untuk DSH Web Server
/// sesuai spesifikasi signing di `@deepseek-ai/dsh-client-connection`.
public struct DshAuthSigner: Sendable {
    public static let cookiePrefix = "dsh-auth-"

    /// Base64URL encoding tanpa padding
    public static func encodeBase64Url(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Base64URL decoding dengan auto padding
    public static func decodeBase64Url(_ string: String) -> Data? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }
        return Data(base64Encoded: base64)
    }

    /// Menghitung nama cookie unik berdasarkan authority (`host:port`).
    /// Formula upstream: `dsh-auth-` + base64url(SHA256(authority))
    public static func cookieName(for authority: String) -> String {
        let hash = SHA256.hash(data: Data(authority.utf8))
        return cookiePrefix + encodeBase64Url(Data(hash))
    }

    /// Membaca secret `client-connection/browser-session` dari `~/.dsh/.credentials.yaml`
    public static func loadSecret(credentialsPath: String = ("~/.dsh/.credentials.yaml" as NSString).expandingTildeInPath) -> Data? {
        guard let content = try? String(contentsOfFile: credentialsPath, encoding: .utf8) else {
            return nil
        }

        let lines = content.components(separatedBy: .newlines)
        for i in 0..<lines.count {
            if lines[i].contains("client-connection/browser-session:") {
                for j in (i + 1)..<min(i + 10, lines.count) {
                    let trimmed = lines[j].trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("secret:") {
                        let parts = trimmed.split(separator: ":", maxSplits: 1)
                        if parts.count == 2 {
                            let secretB64 = parts[1].trimmingCharacters(in: .whitespaces)
                            return decodeBase64Url(secretB64)
                        }
                    }
                }
            }
        }
        return nil
    }

    /// Membuat nilai signed cookie yang valid untuk authority tertentu.
    /// Format: `v1.<bodyBase64Url>.<signatureBase64Url>`
    public static func generateSessionCookie(
        authority: String,
        secret: Data,
        durationDays: Double = 30.0
    ) -> (name: String, value: String)? {
        let issuedAt = Int64(Date().timeIntervalSince1970 * 1000)
        let maxAgeMs = Int64(durationDays * 24 * 60 * 60 * 1000)
        let expiresAt = issuedAt + maxAgeMs

        let payload: [String: Any] = [
            "version": 1,
            "authority": authority,
            "issuedAt": issuedAt,
            "expiresAt": expiresAt
        ]

        guard JSONSerialization.isValidJSONObject(payload),
              let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            return nil
        }

        let bodyBase64Url = encodeBase64Url(jsonData)
        guard let bodyData = bodyBase64Url.data(using: .utf8) else {
            return nil
        }

        let key = SymmetricKey(data: secret)
        let hmac = HMAC<SHA256>.authenticationCode(for: bodyData, using: key)
        let sigBase64Url = encodeBase64Url(Data(hmac))

        let cookieVal = "v1.\(bodyBase64Url).\(sigBase64Url)"
        let cookieName = cookieName(for: authority)

        return (name: cookieName, value: cookieVal)
    }
}
