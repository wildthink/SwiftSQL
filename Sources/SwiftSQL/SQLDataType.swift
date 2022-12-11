// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import Foundation
import SQLite3
/* jmj
/// Represents a data type supported by SQLite.
///
/// - note: To add support for custom data types, like `Bool` or `Date`, see
/// [Advanced Usage Guide](https://github.com/kean/SwiftSQL/blob/0.1.0/Docs/advanced-usage-guide.md)
public protocol SQLDataType {
    func sqlBind(statement: OpaquePointer, index: Int32)
    static func sqlColumn(statement: OpaquePointer, index: Int32) -> Self
}

extension Int: SQLDataType {
    public func sqlBind(statement: OpaquePointer, index: Int32) {
        sqlite3_bind_int64(statement, index, Int64(self))
    }

    public static func sqlColumn(statement: OpaquePointer, index: Int32) -> Int {
        Int(sqlite3_column_int64(statement, index))
    }
}

extension Int32: SQLDataType {
    public func sqlBind(statement: OpaquePointer, index: Int32) {
        sqlite3_bind_int(statement, index, self)
    }

    public static func sqlColumn(statement: OpaquePointer, index: Int32) -> Int32 {
        sqlite3_column_int(statement, index)
    }
}

extension Int64: SQLDataType {
    public func sqlBind(statement: OpaquePointer, index: Int32) {
        sqlite3_bind_int64(statement, index, self)
    }

    public static func sqlColumn(statement: OpaquePointer, index: Int32) -> Int64 {
        sqlite3_column_int64(statement, index)
    }
}

extension Double: SQLDataType {
    public func sqlBind(statement: OpaquePointer, index: Int32) {
        sqlite3_bind_double(statement, index, self)
    }

    public static func sqlColumn(statement: OpaquePointer, index: Int32) -> Double {
        sqlite3_column_double(statement, index)
    }
}

extension String: SQLDataType {
    public func sqlBind(statement: OpaquePointer, index: Int32) {
        sqlite3_bind_text(statement, index, self, -1, SQLITE_TRANSIENT)
    }

    public static func sqlColumn(statement: OpaquePointer, index: Int32) -> String {
        guard let pointer = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: pointer)
    }
}

extension Data: SQLDataType {
    public func sqlBind(statement: OpaquePointer, index: Int32) {
        sqlite3_bind_blob(statement, Int32(index), Array(self), Int32(count), SQLITE_TRANSIENT)
    }

    public static func sqlColumn(statement: OpaquePointer, index: Int32) -> Data {
        guard let pointer = sqlite3_column_blob(statement, Int32(index)) else {
            return Data()
        }
        let count = Int(sqlite3_column_bytes(statement, Int32(index)))
        return Data(bytes: pointer, count: count)
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
*/
