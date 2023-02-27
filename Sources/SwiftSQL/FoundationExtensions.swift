//
//  FoundationExtensions.swift
//  
//
//  Created by Jason Jobe on 2/26/23.
//

import Foundation

// MARK: - Optional, Array Protocols
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
