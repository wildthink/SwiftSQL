// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import Foundation
import SwiftSQL

// Conveniences for commonly used types.
// Note that automatc type conversion is being done;
// this is to maintain the expected type flexibility
// of SQLite.
// From the docs:
// >If the result column is not initially in the requested format (for example, if the query returns an integer but the sqlite3_column_text() interface is used to extract the value) then an automatic type conversion is performed.
// Reference: https://www.sqlite.org/c3ref/column_blob.html
/*
extension Int: InitializableBySQLColumnValue {
    public init?(sqlColumnValue: SQLColumnValue) {
        switch sqlColumnValue {
            case .int64(let int64):
                self = Int(int64)
            case .double(let double):
                self = Int(double)
            case .string(let string):
                if let int = Int(string) {
                    self = int
                } else {
                    return nil
                }
            default:
                return nil
        }
    }
}

extension Int32: InitializableBySQLColumnValue {
    public init?(sqlColumnValue: SQLColumnValue) {
        switch sqlColumnValue {
            case .int64(let int64):
                self = Int32(int64)
            case .double(let double):
                self = Int32(double)
            case .string(let string):
                if let int32 = Int32(string) {
                    self = int32
                } else {
                    return nil
                }
            default:
                return nil
        }
    }
}

extension Int64: InitializableBySQLColumnValue {
    public init?(sqlColumnValue: SQLColumnValue) {
        switch sqlColumnValue {
            case .int64(let int64):
                self = int64
            case .double(let double):
                self = Int64(double)
            case .string(let string):
                if let int64 = Int64(string) {
                    self = int64
                } else {
                    return nil
                }
            default:
                return nil
        }
    }
}

extension Double: InitializableBySQLColumnValue {
    public init?(sqlColumnValue: SQLColumnValue) {
        switch sqlColumnValue {
            case .int64(let int64):
                self = Double(int64)
            case .double(let double):
                self = double
            case .string(let string):
                if let double = Double(string) {
                    self = double
                } else {
                    return nil
                }
            default:
                return nil
        }
    }
}

extension String: InitializableBySQLColumnValue {
    public init?(sqlColumnValue: SQLColumnValue) {
        switch sqlColumnValue {
            case .int64(let int64):
                self = String(int64)
            case .double(let double):
                self = String(double)
            case .string(let string):
                self = string
            default:
                return nil
        }
    }
}

extension Data: InitializableBySQLColumnValue {
    public init?(sqlColumnValue: SQLColumnValue) {
        switch sqlColumnValue {
            case .data(let data):
                self = data
            default:
                return nil
        }
    }
}
*/
