// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import XCTest
import Foundation
import SwiftSQL

/// - WARNING: These tests must be run in release node.
final class PerformanceTests: XCTestCase {
    var tempDir: TempDirectory!
    var storeURL: URL!
    var db: SQLConnection!

    override func setUp() {
        tempDir = try! TempDirectory()
        storeURL = tempDir.file(named: "test-store-perf")
        db = try! SQLConnection(location: .disk(url: storeURL))
    }

    override func tearDown() {
        tempDir = nil
    }

    func xtestWrite() throws {
        try db.execute("""
        CREATE TABLE Users
        (
            Id INTEGER PRIMARY KEY NOT NULL,
            Name VARCHAR,
            Surname VARCHAR,
            Level INTEGER
        )
        """)

        let statement = try db.prepare("""
        INSERT INTO Users (Name, Surname, Level)
        VALUES (?, ?, ?)
        """)
        measure {
            for _ in 0..<500 {
                try! statement
                    .bind("Alice", at: 0)
                    .bind("Tests", at: 1)
                    .bind(Int64(80), at: 2)
                    .execute()

                try! statement.reset()
            }
        }
    }

    func xtestWriteBindArray() throws {
        try db.execute("""
        CREATE TABLE Users
        (
            Id INTEGER PRIMARY KEY NOT NULL,
            Name VARCHAR,
            Surname VARCHAR,
            Level INTEGER
        )
        """)

        let statement = try db.prepare("""
        INSERT INTO Users (Name, Surname, Level)
        VALUES (?, ?, ?)
        """)

        measure {
            for _ in 0..<500 {
                try! statement
                    .bind(["Alice", "Tests", Int64(80)])
                    .execute()

                try! statement.reset()
            }
        }
    }

    func xtestRead() throws {
        try db.execute("""
        CREATE TABLE Users
        (
            Id INTEGER PRIMARY KEY NOT NULL,
            Name VARCHAR,
            Surname VARCHAR,
            Level INTEGER
        )
        """)

        let statement = try db.prepare("""
        INSERT INTO Users (Name, Surname, Level)
        VALUES (:name, :surname, :level)
        """)

        for _ in 0..<2000 {
            try! statement
                .bind(["Alice", "Tests", Int64(80)])
                .execute()

            try! statement.reset()
        }

        measure {
            for _ in 0..<100 {
                let statement = try! db.prepare("""
                SELECT Name, Surname, Level
                FROM Users
                ORDER BY Level ASC
                """)

                var objects = [User]()
                while try! statement.step() {
                    let user = User(
                        name: statement.column(at: 0),
                        surname: statement.column(at: 1),
                        level: statement.column(at: 2)
                    )
                    objects.append(user)
                }
            }
        }
    }
}
