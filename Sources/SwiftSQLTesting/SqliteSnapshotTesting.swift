//
//  SqliteSnapshotTesting.swift
//  
//
//  Created by Jason Jobe on 2/20/23.
//

import Foundation
import SnapshotTesting
import SwiftSQL

extension Snapshotting where Value: SQLConnection, Format == String {
    static func _dump(_ table: String? = nil) -> Snapshotting {
        return SimplySnapshotting.lines.pullback { (db: SQLConnection) in
            do {
                return try DatabaseDumper(db, table: table).dump()
            } catch {
                return "Error: " + error.localizedDescription
            }
        }
    }
}

/*
public extension Snapshotting where Value == DatabaseDumper, Format == String {
    static func _dump() -> Snapshotting {
        return SimplySnapshotting.lines.pullback { (dumper) in
            do {
                return try dumper.dump()
            } catch {
                return "Error: " + error.localizedDescription
            }
        }
    }
}
*/

struct DatabaseDumper {
    var db: SQLConnection
    var table: String?
    
    init(_ db: SQLConnection, table: String? = nil) {
        self.db = db
        self.table = table
    }
    
    func dump() throws -> String {
        guard let table else {
            throw NSError(domain: "sql.test", code: 0)
        }
//        let encoder = JSONEncoder()
//        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let select = try db.prepare("SELECT * FROM \(table)")
        
        var result = "# \(table)\n"
//        let cols = select.columnNames
        
        while try select.step() {
            let row = select.keyValuePairs
            print("(", terminator: "", to: &result)
            let line = row.map { "\($0): \($1)" }.joined(separator: ", ")
            print(line, terminator: ")\n", to: &result)
        }
        print("\n# EOF", to: &result)
        return result
    }
}

public extension Snapshotting where Value == SQLConnection, Format == String {
    /// Snapshot strategy for comparing databases based on dump representation.
//    static let dbDump = _dump()
    static func dbDumpTable(_ table: String) -> Self {
        _dump(table)
    }
}

/*
public extension Snapshotting where Value == DatabaseQueue, Format == String {
    /// Snapshot strategy for comparing databases based on dump representation.
    static let dbDump = _dump()
}

public extension Snapshotting where Value == DatabasePool, Format == String {
    /// Snapshot strategy for comparing databases based on dump representation.
    static let dbDump = _dump()
}
*/
