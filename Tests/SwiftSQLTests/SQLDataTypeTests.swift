// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import XCTest
import Foundation
import SwiftSQL
import SnapshotTesting

final class SQLDataTypeTests: XCTestCase {
    var db: SQLConnection!

    override func setUp() {
        super.setUp()
        let path = "/Users/jason/data/xctest.db"

//        db = try! SQLConnection(location: .memory())
        try? FileManager.default.removeItem(atPath: path)
        db = try! SQLConnection(url: URL(fileURLWithPath: path))
    }

    func testRun() throws {
        // CREATE Table
        try db.execute("""
            CREATE TABLE Test (
            id INTEGER PRIMARY KEY,
            i INTEGER,
            f REAL,
            b BLOB,
            t TEXT,
            ja LIST
        )
        """)

        let insert = try db.prepare("""
            INSERT INTO Test (id, i, f, b, t, ja) VALUES (?,?,?,?,?,?)
        """)
        
        try insert
            .bind(1, 10, 10.25, Data(), "string", "[1, 2, 3]")
            .execute()
        print("Done", #function)
    }
    
    func testInt32() throws {
        try db.execute("CREATE TABLE Test (Field INTEGER)")

        // WHEN/THEN binds the value
        try db.prepare("INSERT INTO Test (Field) VALUES (?)")
            .bind(Int32.max)
            .execute()

        // WHEN/THEN reads the value
        let statement = try db.prepare("SELECT Field FROM Test")
        XCTAssertTrue(try statement.step())
        XCTAssertEqual(statement.column(at: 0), Int32.max)
    }

    func testInt64() throws {
        try db.execute("CREATE TABLE Test (Field INTEGER)")

        // WHEN/THEN binds the value
        try db.prepare("INSERT INTO Test (Field) VALUES (?)")
            .bind(Int64.max)
            .execute()

        // WHEN/THEN reads the value
        let statement = try db.prepare("SELECT Field FROM Test")
        XCTAssertTrue(try statement.step())
        XCTAssertEqual(statement.column(at: 0), Int64.max)
    }

    func testString() throws {
        try db.execute("CREATE TABLE Test (Field VARCHAR)")

        // WHEN/THEN binds the value
        try db.prepare("INSERT INTO Test (Field) VALUES (?)")
            .bind("Test")
            .execute()

        // WHEN/THEN reads the value
        let statement = try db.prepare("SELECT Field FROM Test")
        XCTAssertTrue(try statement.step())
        XCTAssertEqual(statement.column(at: 0), "Test")
    }

    func testDouble() throws {
        try db.execute("CREATE TABLE Test (Field REAL)")

        // WHEN/THEN binds the value
        try db.prepare("INSERT INTO Test (Field) VALUES (?)")
            .bind(10.5)
            .execute()

        // WHEN/THEN reads the value
        let statement = try db.prepare("SELECT Field FROM Test")
        XCTAssertTrue(try statement.step())
        let pl = statement.dictionaryValue
        print(statement.sql() ?? "", pl)
        XCTAssertEqual(statement.column(at: 0), 10.5)
    }

    func testNilString() throws {
        try db.execute("CREATE TABLE Test (Field VARCHAR)")

        // WHEN/THEN binds the value
        try db.prepare("INSERT INTO Test (Field) VALUES (?)")
            .bind(nil)
            .execute()

        // WHEN/THEN reads the value
        let statement = try db.prepare("SELECT Field FROM Test")
        XCTAssertTrue(try statement.step())
        XCTAssertEqual(statement.column(at: 0) as String?, nil)
    }

    func testNilInt() throws {
        try db.execute("CREATE TABLE Test (Field INTEGER)")

        // WHEN/THEN binds the value
        try db.prepare("INSERT INTO Test (Field) VALUES (?)")
            .bind(nil)
            .execute()

        // WHEN/THEN reads the value
        let statement = try db.prepare("SELECT Field FROM Test")
        XCTAssertTrue(try statement.step())
        XCTAssertEqual(statement.column(at: 0) as Int32?, nil)
    }
}
