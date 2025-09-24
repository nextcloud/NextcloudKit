//  SPDX-FileCopyrightText: 2025 Nextcloud GmbH and Nextcloud contributors
//  SPDX-License-Identifier: GPL-3.0-or-later

///
/// The [`files_lock`](https://github.com/nextcloud/files_lock) server apps distinguishes between different lock types which are represented by this type.
///
public enum NKLockType: Int, Sendable {
    ///
    /// This lock type is initiated by a user manually through the WebUI or Clients and will limit editing capabilities on the file to the lock owning user.
    ///
    case user = 0

    ///
    /// This lock type is created by collaborative apps like Text or Office to avoid outside changes through WebDAV or other apps.
    ///
    case app = 1

    ///
    /// This lock type will bind the ownership to the provided lock token.
    /// Any request that aims to modify the file will be required to sent the token, the user itself is not able to write to files without the token.
    /// This will allow to limit the locking to an individual client.
    ///
    /// This is mostly used for automatic client locking, e.g. when a file is opened in a client or with WebDAV clients that support native WebDAV locking.
    /// The lock token can be skipped on follow up requests using the OCS API or the X-User-Lock header for WebDAV requests, but in that case the server will not be able to validate the lock ownership when unlocking the file from the client.
    ///
    case token = 2
}
