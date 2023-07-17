//
//  Image+Extension.swift
//  NextcloudKit
//
//  Created by Marino Faggiana on 21/12/20.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
//  Copyright © 2021 Henrik Storch. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//  Author Henrik Storch <henrik.storch@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

#if os(iOS)
import UIKit

extension UIImage {
    internal func resizeImage(size: CGSize, isAspectRation: Bool) -> UIImage? {
        let originRatio = self.size.width / self.size.height
        let newRatio = size.width / size.height
        var newSize = size

        if isAspectRation {
            if originRatio < newRatio {
                newSize.height = size.height
                newSize.width = size.height * originRatio
            } else {
                newSize.width = size.width
                newSize.height = size.width / originRatio
            }
        }

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        self.draw(in: CGRect(origin: .zero, size: newSize))
        defer { UIGraphicsEndImageContext() }
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
#endif

#if os(macOS)
import Foundation
import AppKit

public typealias UIImage = NSImage

public extension NSImage {
    var cgImage: CGImage? {
        var proposedRect = CGRect(origin: .zero, size: size)

        return cgImage(forProposedRect: &proposedRect,
                       context: nil,
                       hints: nil)
    }

    func jpegData(compressionQuality: Double) -> Data? {
        if let bits = self.representations.first as? NSBitmapImageRep {
            return bits.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
        }

        return nil
    }

    func pngData() -> Data? {
        if let bits = self.representations.first as? NSBitmapImageRep {
            return bits.representation(using: .png, properties: [:])
        }

        return nil
    }

    func resizeImage(size: CGSize, isAspectRation: Bool) -> NSImage? {
        if let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) {
            bitmapRep.size = size
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
            draw(in: NSRect(x: 0, y: 0, width: size.width, height: size.height), from: .zero, operation: .copy, fraction: 1.0)
            NSGraphicsContext.restoreGraphicsState()

            let resizedImage = NSImage(size: size)
            resizedImage.addRepresentation(bitmapRep)
            return resizedImage
        }

        return nil
    }
}
#endif
