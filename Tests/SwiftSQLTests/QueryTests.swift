//
//  QueryTests.swift
//  
//
//  Created by Jason Jobe on 2/5/23.
//

import XCTest
import SwiftSQL
import SwiftSQLExt
//import KeyValueCoding
import SnapshotTesting

final class QueryTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testQuery() throws {
        let db = try SQLConnection(location: .memory())
        @Query(db: db) var qry: Topic = .defaultValue()

        $qry.search = "foo"
        $qry.wrappedValue.set("foo", to: "")
        
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }
}

import SwiftUI
import Combine

extension SQLConnection: EnvironmentKey {
    public static let defaultValue: SQLConnection
                = try! SQLConnection(location: .memory())
}

extension EnvironmentValues {
    public var dataStore: SQLConnection {
        get {
            self[SQLConnection.self]
        } set {
            self[SQLConnection.self] = newValue
        }
    }
}

@propertyWrapper
@dynamicMemberLookup
class Box<A>: ObservableObject {
    var wrappedValue: A
    
    init(_ wrappedValue: A) {
        self.wrappedValue = wrappedValue
    }
    
    subscript<V>(dynamicMember keyp: WritableKeyPath<A,V>) -> V {
        get { wrappedValue[keyPath: keyp] }
        set { wrappedValue[keyPath: keyp] = newValue }
    }
}

@propertyWrapper
struct Query<Value>: DynamicProperty {
    typealias Value = Value
//    @Environment(\.dataStore) var dataStore: SQLConnection
    @State var db: SQLConnection?
   // A state object that we notify of updates
    @StateObject private var watcher: Watcher
    
    init(wrappedValue: Value, db: SQLConnection) {
        self.db = db
        self._watcher = .init(wrappedValue: Watcher(db: db))
    }
    
    var wrappedValue: Value {
        get {
            watcher.value!
        }
        nonmutating set {
            // Tell SwiftUI we're going to change something
            watcher.notifyUpdate()
            // Your setter code here
        }
    }
    
    public var projectedValue: Box<SQLPredicate> {
        get { Box(watcher.cond) }
        set { print(newValue) }
    }
    
//    public var projectedValue: Binding<SQLPredicate> {
//        return Binding(get: { watcher.cond },
//                       set: { _ in }
//        )
//    }
//    public var projectedValue: Binding<T.Filter> {
//        return Binding(get: { core.filter ?? baseFilter },
//                       set: {
//            if core.filter != $0 {
//                core.objectWillChange.send()
//                core.filter = $0
//            }
//        })
//    }
    
    class Watcher: ObservableObject {
        var db: SQLConnection
        var value: Value?
        var task: Task<Value, Error>?
        var cond: SQLPredicate = .init(search: "")
        
        init(db: SQLConnection) {
            self.db = db
        }
        
        deinit {
            task?.cancel()
        }
        
        func notifyUpdate() {
            objectWillChange.send()
        }
    }
}

public struct SQLPredicate: Equatable {
    var search: String
    
    mutating func callAsFunction(_ key: String) {
        
    }
    
    mutating func set(_ key: String, to value: String) {
        
    }
    
    subscript(_ key: String) -> String {
        get { search }
        set { search = newValue }
    }
}
