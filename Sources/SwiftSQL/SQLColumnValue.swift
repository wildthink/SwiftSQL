// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import Foundation

public enum SQLColumnValue: Equatable {
    case int64(Int64)
    case double(Double)
    case string(String)
    case data(Data)
    case null
}

extension SQLColumnValue: CustomStringConvertible {
    public var description: String {
        switch self {
            case .data(let data):
                return String(describing: data)
            case .double(let value):
                return String(describing: value)
            case .int64(let value):
                return String(describing: value)
            case .string(let value):
                return "\"\(value)\""
            case .null:
                return "null"
        }
    }
 }
