// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

/// Utility namespace for constructing Nextcloud WebDAV (DAV) endpoint paths.
///
/// The standard DAV structure in Nextcloud is:
/// `<baseURL>/remote.php/dav/files/<userId>/`
public enum NKDav {

    // Base DAV endpoint used by Nextcloud
    public static let basePath = "/remote.php/dav/"

    // Files namespace within DAV
    public static let filesPath = "files/"

    /// Builds the user DAV path with trailing slash
    /// Example: /remote.php/dav/files/<userId>/
    public static func userPath(userId: String) -> String {
        basePath + filesPath + userId + "/"
    }

    /// Builds the user DAV path without trailing slash
    /// Example: /remote.php/dav/files/<userId>
    public static func userPathNoSlash(userId: String) -> String {
        basePath + filesPath + userId
    }

    /// Full DAV URL (with trailing slash)
    public static func homeURLString(urlBase: String, userId: String) -> String {
        urlBase + userPath(userId: userId)
    }

    /// Full DAV URL (without trailing slash)
    public static func homeURLStringNoSlash(urlBase: String, userId: String) -> String {
        urlBase + userPathNoSlash(userId: userId)
    }
}
