//
//  Storable.swift
//  
//
//  Created by Jason Jobe on 2/23/23.
//

import Foundation

public protocol OptionalProtocol {
    static var honestType: Any.Type { get }
    var honestValue: Any? { get }
}

extension Optional: OptionalProtocol {    
    public static var honestType: Any.Type { Wrapped.self }
    public var honestValue: Any? { return self }
}

public protocol ArrayProtocol {
    static var elementType: Any.Type { get }
    static func empty() -> Self
}

extension Array: ArrayProtocol {
    public static var elementType: Any.Type {
        Element.self
    }
    public static func empty() -> Array<Element> {
        Self()
    }
}

// MARK: Storable
public typealias StorableRepresentation = Storable

public protocol Storable {
    var storableRepresentation: StorableRepresentation { get }
}

extension Optional: Storable where Wrapped: Storable {
    public var storableRepresentation: StorableRepresentation {
        switch self {
            case .none: return self
            case .some(let s): return s.storableRepresentation
        }
    }
}

public protocol BuiltinStorable: Storable {
    var builtinRepresentation: Any { get }
}

extension BuiltinStorable {
    
    public var builtinRepresentation: Any { self }
    public var storableRepresentation: StorableRepresentation {
        self
    }
}

// TODO: Add Date and JSON as Storables
extension Date: Storable {
    
    public var storableRepresentation: StorableRepresentation {
        let bitPattern = self.timeIntervalSinceReferenceDate.bitPattern
        return String(bitPattern) // .builtinRepresentation as! StorableRepresentation
    }
}

// TODO: Move to SQLStatement
import SQLite3

extension Data:   BuiltinStorable {}
extension String: BuiltinStorable {}
extension Bool:   BuiltinStorable {}

// FixedWidthInteger
extension Int:   BuiltinStorable {}
extension Int8:  BuiltinStorable {}
extension Int16: BuiltinStorable {}
extension Int32: BuiltinStorable {}
extension Int64: BuiltinStorable {}

// BinaryFloatingPoint
extension CGFloat: BuiltinStorable {}
extension Float16: BuiltinStorable {}
extension Float32: BuiltinStorable {}
extension Float64: BuiltinStorable {}

extension SQLStatement {

    @_disfavoredOverload
    public func value<T: Storable>(
        at index: Int,
        as t: T.Type = T.self)
    throws -> T? {
        self.anyValue(at: index) as? T
    }

    public func value<T: Storable>(at ndx: Int, as t: T.Type = T.self)
    throws -> T
    where T: FixedWidthInteger
    {
        let v = self.anyValue(at: ndx)
        if let v, let r = v as? T { return r }
        if let v = v as? (any FixedWidthInteger) {
            return T(v)
        }
        throw SQLError(code: #line,
                message: "Unable to cast \(String(describing: v)) at \(ndx) to \(t)")
    }

    public func value<T: Storable>(at ndx: Int, as t: T.Type = T.self)
    throws -> T {
        let v = self.anyValue(at: ndx)
        if let v, let r = v as? T { return r }
        throw SQLError(code: #line,
                       message: "Unable to cast \(String(describing: v)) at \(ndx) to \(t)")
    }
    
    @discardableResult
    public func bind(_ parameters: Storable?...) throws -> Self {
        try bind(parameters)
        return self
    }

    @discardableResult
    public func bind(_ parameters: [Storable?]) throws -> Self {
        for (index, value) in zip(parameters.indices, parameters) {
            try bind(value: value, at: Int(index + 1))
        }
        return self
    }
    /// Binds values to the named statement parameters.
    ///
    ///     let row = try db.prepare("SELECT Level, Name FROM Users WHERE Name = :param LIMIT 1")
    ///         .bind([":param": "John""])
    ///         .next()
    ///
    /// - parameter name: The name of the parameter. If the name is missing, throws
    /// an error.
    @discardableResult
    public func bind(_ parameters: [String: Storable?]) throws -> Self {
        for (key, value) in parameters {
            try bind(value, for: key)
        }
        return self
    }

    @discardableResult
    public func bind(_ value: Storable?, for name: String) throws -> Self {
        let ndx = sqlite3_bind_parameter_index(ref, name)
        guard ndx > 0 else {
            throw SQLError(code: SQLITE_MISUSE, message: "Failed to find parameter named \(name)")
        }
        return try bind(value, at: Int(ndx-1))
    }

    // MARK: - Bind
    @_disfavoredOverload
    public func bind(_ value: Any?, at index: Int) throws -> Self {
        guard let value else {
            sqlite3_bind_null(ref, Int32(index))
            return self
        }
        if let builtin = value as? Storable {
            return try bind(builtin, at: index)
        }
        // else
        throw SQLError(code: #line, message: "Unsupport type \(type(of: value))")
    }
    
    public func bind(_ value: Storable?, at index: Int) throws -> Self {
        guard let value else {
            // The leftmost SQL parameter has an index of 1.
            sqlite3_bind_null(ref, Int32(index+1))
            return self
        }
        if let builtin = value as? BuiltinStorable {
            try bind(value: builtin, at: index)
        } else {
            try bind(value: value.storableRepresentation, at: index)
        }
        return self
    }
    
    /*
     Binding Values To Prepared Statements
     https://www.sqlite.org/c3ref/bind_blob.html
     
     The second argument is the index of the SQL parameter to be set. The leftmost SQL
     parameter has an index of 1. When the same named SQL parameter is used more than
     once, second and subsequent occurrences have the same index as the first occurrence.
     The index for named parameters can be looked up using the sqlite3_bind_parameter_index()
     API if desired. The index for "?NNN" parameters is the value of NNN. The NNN value
     must be between 1 and the sqlite3_limit() parameter SQLITE_LIMIT_VARIABLE_NUMBER
     (default value: 32766).
     */
    func bind(value: BuiltinStorable?, at index: Int) throws {
//        guard index > 0 else {
//            throw SQLError(code: #line, message: "Bind index \(index) is out of bounds")
//        }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        
        let index = Int32(index+1)
        if value == nil {
            sqlite3_bind_null(ref, index)
        }
        else if let value = value as? Data {
            sqlite3_bind_blob(ref, index, Array(value), Int32(value.count), SQLITE_TRANSIENT)
        }
        else if let value = value as? (any FixedWidthInteger) {
            sqlite3_bind_int64(ref, index, Int64(value))
        }
        else if let value = value as? (any BinaryFloatingPoint) {
            sqlite3_bind_double(ref, index, Double(value))
        }
        else if let value = value as? String {
            sqlite3_bind_text(ref, index, value,
                              -1, SQLITE_TRANSIENT)
        }
        else if let value = value as? (any StringProtocol) {
            sqlite3_bind_text(ref, index, String(value),
                              -1, SQLITE_TRANSIENT)
        }
        else {
            throw SQLError(code: #line, message: "Cannot bind value of type \(type(of: value))")
        }
    }

}
