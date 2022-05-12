//
//  File.swift
//  
//
//  Created by Jason Jobe on 4/16/22.
//

import Foundation

public struct Converter {
    public let key: String
    public let a_type: Any.Type
    public let b_type: Any.Type
    var atob: (Any) throws -> Any
    var btoa: (Any) throws -> Any
}

extension Converter {
    init<A,B>(_ key: String, atob: @escaping (A) throws -> B, btoa: @escaping (B) throws -> A) {
        self.key = key
        a_type = A.self
        b_type = B.self
        self.atob = atob as! (Any) throws -> Any
        self.btoa = btoa as! (Any) throws -> Any
    }
}
