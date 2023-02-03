//
//  File.swift
//  
//
//  Created by Jason Jobe on 2/2/23.
//

import Foundation
import KeyValueCoding

public extension Metadata {
    var isOptional: Bool { kind == .optional }
}

extension Metadata.Property {
    var isOptional: Bool { metadata.isOptional }
}

protocol OptionalProtocol {
    static var honestType: Any.Type { get }
}

extension Optional: OptionalProtocol {
    static var honestType: Any.Type { Wrapped.self }
}

protocol ArrayProtocol {
    static var elementType: Any.Type { get }
    static func empty() -> Self
}

extension Array: ArrayProtocol {
    static var elementType: Any.Type {
        Element.self
    }
    static func empty() -> Array<Element> {
        Self()
    }
}

public struct Schema {
    var name: String
    var int: Int?
    var valueType: Any.Type
    var md: Metadata { swift_metadata(of: valueType) }
}

extension Schema {
    
    func type_decl(for md: Metadata) -> String {
        switch md.type {
            case is Date.Type:
                return "DATE"
            case is Data.Type:
                return "BLOB"
            case is String.Type:
                return "TEXT"
            case is ArrayProtocol.Type:
                return "LIST"
            case is any BinaryFloatingPoint.Type:
                return "REAL"
            case is any FixedWidthInteger.Type:
                return "INT"
                
            case let it as any OptionalProtocol.Type:
                return type_decl(for: swift_metadata(of: it.honestType))
                
            default:
                return ""
        }
    }
    
    func type_decl(for p: Metadata.Property) -> String {
        type_decl(for: p.metadata)
    }
    
    func sql_decl(for p: Metadata.Property, strict: Bool = true) -> String {
        if strict {
            return "\(p.name) \(type_decl(for: p))\(p.isOptional ? "" : " NOT NULL")"
        } else {
            return "\(p.name) \(type_decl(for: p))"
        }
    }
}


//func Line(@ArrayBuilder<String> f: () -> [String]) -> String {
//    f().joined(separator: "")
//}

public func Joined(with sep: String = "", @ArrayBuilder<String> f: () -> [String]) -> String {
    f().joined(separator: sep)
}

public extension Schema {
    
    func sql(create table: String) -> String {
        [String]() {
            "CREATE TABLE \(table) ("
            for p in md.properties {
                "\t" + sql_decl(for: p)
                    .append(",", if: { p.name != md.properties.last?.name })
            }
            ");"
        }
        .joined(separator: "\n")
    }
    
    func sql(insert table: String) -> String {
        [String]() {
            "INSERT INTO \(table)"
            Joined(with: ",") {
                tab()
                for p in md.properties {
                    p.name
                }
            }
            ");"
        }
        .joined(separator: "\n")
    }
}

public func tab(_ cnt: Int = 1) -> String {
    cnt == 1 ? "\t" : String(repeating: "\t", count: cnt)
}

public func newline(_ cnt: Int = 1) -> String {
    cnt == 1 ? "\t" : String(repeating: "\n", count: cnt)
}


public extension String {
    func append(_ s: String, if cond: () -> Bool) -> String {
        cond() ? self + s : self
    }
    
    func transform(if cond: () -> Bool, fn: (String) -> String) -> String {
        cond() ? fn(self) : self
    }
    
    func `if`(_ cond: () -> Bool, fn: (String) -> String) -> String {
        cond() ? fn(self) : self
    }
    
}

public extension Schema {
    init(_ name: String? = nil, for t: Any.Type) {
        self.valueType = t
        self.name = name ?? String(describing: t)
    }
}

public extension Array {
    init(@ArrayBuilder<Element> makeItems: () -> [Element]) {
        self.init(makeItems())
    }
}
