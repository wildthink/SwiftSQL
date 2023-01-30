// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import Foundation
import SQLite3

/// Represents an SQLite error.
public struct SQLError: Swift.Error {
    /// The [error code](https://www.sqlite.org/c3ref/c_abort.html).
    public let code: Int32

    /// The [error message](https://www.sqlite.org/c3ref/errcode.html).
    public var message: String

    init?(code: Int32, db: OpaquePointer) {
        guard !(code == SQLITE_ROW || code == SQLITE_OK || code == SQLITE_DONE) else { return nil }

        self.code = code
        self.message = String(cString: sqlite3_errmsg(db))
    }

    public init(code: Int32, message: String) {
        self.code = code
        self.message = message
    }
}
