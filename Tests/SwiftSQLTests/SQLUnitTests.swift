//
//  SQLUnitTests.swift
//  
//
//  Created by Jason Jobe on 1/29/23.
//

import SnapshotTesting
import XCTest
@testable import SwiftSQL
import SQLite3

final class SQLUnitTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testSelect() throws {
        /// GIVEN
        let db = try SQLConnection(location: .memory())
        try db.execute("""
         CREATE TABLE test
        (
            Id INTEGER PRIMARY KEY NOT NULL,
            Name VARCHAR,
            Level INTEGER,
            number REAL,
            thunk BLOB
        )

        """)

        let insert = try db.prepare("""
        INSERT INTO test (id, level, name, number, thunk)
        VALUES (?, ?, ?, ?, ?)
        """)

        // WHEN
        try insert
            .bind(80, at: 0)
            .bind("Alex", at: 1)
            .bind(66, at: 2)
            .bind(43.5, at: 3)
            .bind("foo".data(using: .ascii), at: 4)
            .execute()

        // THEN
        let select = try db.prepare("SELECT * FROM test")
        XCTAssertTrue(try select.step())
        let row = select.dictionaryValue
        assertSnapshot(matching: row, as: .dump)

        let data: Data = try select.value(at: 4)
        let str: String = try select.value(at: 1)
        let real: Double = try select.value(at: 3)
        let int: Int = try select.value(at: 2)
        assertSnapshot(matching: (data, str, real, int), as: .dump)
    }

    func testDatabaseHooks() throws {
        let db = try SQLConnection(location: .memory())
        var didCommit = false
        var didRollback = false

        db.createCommitHandler {
            print("commit")
            didCommit = true
        }
        db.createRollbackHandler {
            print("rollback")
            didRollback = true
        }
        db.createUpdateHandler { info in
            print(info,
                  info.isDelete,
                  info.isInsert,
                  info.isUpdate)
            assertSnapshot(matching: info, as: .dump)
        }

        try db.execute("CREATE TABLE Test (Field VARCHAR)")
        try db.execute("INSERT INTO Test VALUES ('Howdy')")
//        try db.execute("COMMIT")
        try db.execute("""
            BEGIN;
            INSERT INTO Test VALUES ('Howdy');
            ROLLBACK;
        """)

        db.removeCommitHandler()
        db.removeUpdateHandler()
        db.removeRollbackHandler()

        XCTAssertTrue(didCommit)
        XCTAssertTrue(didRollback)
        print ("Pass", #function)
    }

    func testBinders() throws {

        let b: [SQLBinder] = [
            Int.defaultSQLBinder,
            Int32.defaultSQLBinder,
            Float.defaultSQLBinder]

        let id = Int64.defaultSQLBinder.named("id")
        print(id)
//        assertSnapshot(matching: id, as: .dump)
        assertSnapshot(matching: b, as: .dump)
    }

    func testSQLErrors() throws {
        let db = try SQLConnection(location: .memory())
        try db.execute("CREATE TABLE Test (Field VARCHAR)")

        let e1 = SQLError(code: 0, message: "E1 Error")
        assertSnapshot(matching: e1, as: .dump)

        let e2 = SQLError(code: SQLITE_ROW, db: db.ref)
        assertSnapshot(matching: e2, as: .dump)

        let e3 = SQLError(code: 666, db: db.ref)
        assertSnapshot(matching: e3, as: .dump)

    }
}
