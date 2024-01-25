import Foundation
import Combine
import SQLite3
//import SwiftSQL

// MARK: - SQLite hooks

public extension SQLConnection {
    
    func publisher() -> AnyPublisher<Hook.Event, Never> {
        _hook.publisher()
    }
    
    struct UpdateInfo: CustomStringConvertible {
        public let database: String
        public let tableName: String
        public let op_code: Int32
        public let rowid: Int64
        
        init(op: Int32,
             db: UnsafePointer<Int8>?,
             table: UnsafePointer<Int8>?,row: Int64)
        {
            self.op_code = op
            self.rowid = row

            if let name = db {
                self.database = String(cString: name)
            }
            else { self.database = "main" }
            
            if let name = table {
                self.tableName = String(cString: name)
            }
            else { self.tableName = "<table>" }
        }
        
        public var description: String {
            "\(database):\(tableName) \(op)(\(rowid))"
        }
        
        var isInsert: Bool { op_code == SQLITE_INSERT }
        var isUpdate: Bool { op_code == SQLITE_UPDATE }
        var isDelete: Bool { op_code == SQLITE_DELETE }
        
        var op: String {
            switch op_code {
                case SQLITE_UPDATE: return "update"
                case SQLITE_DELETE: return "delete"
                case SQLITE_INSERT: return "insert"
                default:
                    return "<op>"
            }
        }
    }
    
    func createUpdateHandler(_ block: @escaping (UpdateInfo) -> Void) {
        
        let updateBlock: UpdateHookCallback = { _, op, dbName, tableName, rowid in
            guard let tableName = tableName else { return }
            let info = UpdateInfo(op: op, db: dbName, table: tableName, row: rowid)
            block(info)
//            block(String(cString: tableName))
        }
        
        _hook.update = updateBlock
        let hookAsContext = Unmanaged.passUnretained(_hook).toOpaque()
        sqlite3_update_hook(ref, updateHookWrapper, hookAsContext)
    }
    
    func removeUpdateHandler() {
        sqlite3_update_hook(ref, nil, nil)
        _hook.update = nil
    }
    
    func createCommitHandler(_ block: @escaping () -> Void) {
        _hook.commit = block
        let hookAsContext = Unmanaged.passUnretained(_hook).toOpaque()
        sqlite3_commit_hook(ref, commitHookWrapper, hookAsContext)
    }
    
    func removeCommitHandler() {
        sqlite3_commit_hook(ref, nil, nil)
        _hook.commit = nil
    }
    
    func createRollbackHandler(_ block: @escaping () -> Void) {
        _hook.rollback = block
        let hookAsContext = Unmanaged.passUnretained(_hook).toOpaque()
        sqlite3_rollback_hook(ref, rollbackHookWrapper, hookAsContext)
    }
    
    func removeRollbackHandler() {
        sqlite3_rollback_hook(ref, nil, nil)
        _hook.rollback = nil
    }
}


// MARK: - Hook Interface
typealias UpdateHookCallback =
    (UnsafeMutableRawPointer?, Int32, UnsafePointer<Int8>?, UnsafePointer<Int8>?, Int64) -> Void


import SwiftUI
import Combine

public class Hook {
    public enum Event { case didRollback, didCommit, didUpdate(SQLConnection.UpdateInfo) }

    var update: UpdateHookCallback?
    var commit: (() -> Void)?
    var rollback: (() -> Void)?
    var _publisher: PassthroughSubject<Event, Never> = .init()
    
    public init() {
    }
    
    func publisher() -> AnyPublisher<Event, Never> {
        _publisher.eraseToAnyPublisher()
    }
    
    func registerHandlers(_ db: SQLConnection) {
        db.createCommitHandler { [weak self] in
            self?._publisher.send(.didCommit)
        }
        db.createRollbackHandler { [weak self] in
            self?._publisher.send(.didRollback)
        }
        db.createUpdateHandler { [weak self] in
            self?._publisher.send(.didUpdate($0))
        }
    }
}

public extension Hook {
    static var `default`: Hook = Hook()
}

func updateHookWrapper(
    context: UnsafeMutableRawPointer?,
    operationType: Int32,
    databaseName: UnsafePointer<Int8>?,
    tableName: UnsafePointer<Int8>?,
    rowid: sqlite3_int64
) -> Void {
    guard let context = context else { return }
    let hook = Unmanaged<Hook>.fromOpaque(context).takeUnretainedValue()
    hook.update?(context, operationType, databaseName, tableName, rowid)
}

func commitHookWrapper(context: UnsafeMutableRawPointer?) -> Int32 {
    guard let context = context else { return 0 }
    let hook = Unmanaged<Hook>.fromOpaque(context).takeUnretainedValue()
    hook.commit?()
    return 0
}

func rollbackHookWrapper(context: UnsafeMutableRawPointer?) {
    guard let context = context else { return }
    let hook = Unmanaged<Hook>.fromOpaque(context).takeUnretainedValue()
    hook.rollback?()
}
