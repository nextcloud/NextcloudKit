// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire

extension String {
    public var urlEncoded: String? {
        // +        for historical reason, most web servers treat + as a replacement of whitespace
        // ?, &     mark query pararmeter which should not be part of a url string, but added seperately
        let urlAllowedCharSet = CharacterSet.urlQueryAllowed.subtracting(["+", "?", "&"])
        return addingPercentEncoding(withAllowedCharacters: urlAllowedCharSet)
    }

    public var encodedToUrl: URLConvertible? {
        return urlEncoded?.asUrl
    }

    public var asUrl: URLConvertible? {
        return try? asURL()
    }

    public var withRemovedFileExtension: String {
        return String(NSString(string: self).deletingPathExtension)
    }

    public var fileExtension: String {
        return String(NSString(string: self).pathExtension)
    }

    func parsedDate(using format: String) -> Date? {
        NKLogFileManager.shared.convertDate(self, format: format)
    }
}
