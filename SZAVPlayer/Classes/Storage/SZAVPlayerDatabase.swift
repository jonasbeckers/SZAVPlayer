//
//  SZAVPlayerDatabase.swift
//  SZAVPlayer
//
//  Created by CaiSanze on 2019/11/28.
//

import UIKit

public class SZAVPlayerDatabase: NSObject {

    public static let shared = SZAVPlayerDatabase()

    private let dbQueue = SZDatabase()
    private let dbFileName = SZAVPlayerFileSystem.documentsDirectory.appendingPathComponent("SZAVPlayer.sqlite").absoluteString

    override init() {
        super.init()

        guard dbQueue.open(dbPath: dbFileName) else { return }

        createMIMETypesTable()
        createLocalFileInfoTable()
    }

    deinit {
        dbQueue.closeDB()
    }

}

// MARK: - ContentInfo

extension SZAVPlayerDatabase {

    public func contentInfo(uniqueID: String) -> SZAVPlayerContentInfo? {
        var info: SZAVPlayerContentInfo?
        dbQueue.inQueue { (db) in
            let sql = "SELECT * FROM \(SZAVPlayerContentInfo.tableName) WHERE uniqueID = ?"
            let infos = db.query(sql: sql, params: [uniqueID])
            if let infoDict = infos.first,
                let tmpInfo = SZAVPlayerContentInfo.deserialize(data: infoDict)
            {
                info = tmpInfo
            }
        }

        return info
    }

    public func update(contentInfo: SZAVPlayerContentInfo) {
        dbQueue.inQueue { (db) in
            let sql = "INSERT OR REPLACE INTO \(SZAVPlayerContentInfo.tableName) " +
            "(uniqueID, mimeType, contentLength, updated) " +
            "values(?, ?, ?, ?)"
            let updated = Int64(Date().timeIntervalSince1970)
            let params: [Any] = [contentInfo.uniqueID, contentInfo.mimeType, contentInfo.contentLength, updated]
            db.execute(sql: sql, params: params)
        }
    }

    public func deleteMIMEType(uniqueID: String) {
        dbQueue.inQueue { (db) in
            let sql = "DELETE FROM \(SZAVPlayerContentInfo.tableName) WHERE uniqueID = ?"
            let params = [
                uniqueID
            ]
            db.execute(sql: sql, params: params)
        }
    }

    private func createMIMETypesTable() {
        let tableName = SZAVPlayerContentInfo.tableName
        let sqlQuerys = [
            "CREATE TABLE IF NOT EXISTS \(tableName) (" +
            "id INTEGER PRIMARY KEY ASC, " +
            "uniqueID TEXT, " +
            "mimeType TEXT, " +
            "contentLength INTEGER, " +
            "updated INTEGER" +
            ");\n",
            "CREATE UNIQUE INDEX IF NOT EXISTS \(tableName)_uniqueID " +
            "ON \(tableName)(" +
            "uniqueID" +
            ");\n",
        ]

        createTable(sqlQuerys: sqlQuerys)
    }

}

// MARK: - LocalFileInfo

extension SZAVPlayerDatabase {

    public func localFileInfos(uniqueID: String) -> [SZAVPlayerLocalFileInfo] {
        var fileInfos: [SZAVPlayerLocalFileInfo] = []
        dbQueue.inQueue { (db) in
            let sql = "SELECT * FROM \(SZAVPlayerLocalFileInfo.tableName) WHERE uniqueID = ? AND loadedByteLength > 0 ORDER BY startOffset ASC"
            let params = [
                uniqueID
            ]
            let infos = db.query(sql: sql, params: params)
            infos.forEach { (info) in
                if let fileInfo = SZAVPlayerLocalFileInfo.deserialize(data: info) {
                    fileInfos.append(fileInfo)
                }
            }
        }

        return fileInfos
    }

    public func update(fileInfo: SZAVPlayerLocalFileInfo) {
        dbQueue.inQueue { (db) in
            let sql = "INSERT OR REPLACE INTO \(SZAVPlayerLocalFileInfo.tableName) " +
            "(uniqueID, startOffset, loadedByteLength, localFileName, updated) " +
            "values(?, ?, ?, ?, ?)"
            let updated = Int64(Date().timeIntervalSince1970)
            let params: [Any] = [
                fileInfo.uniqueID,
                fileInfo.startOffset,
                fileInfo.loadedByteLength,
                fileInfo.localFileName,
                updated
            ]
            db.execute(sql: sql, params: params)
        }
    }

    public func deleteLocalFileInfo(uniqueID: String) {
        dbQueue.inQueue { (db) in
            let sql = "DELETE FROM \(SZAVPlayerLocalFileInfo.tableName) WHERE uniqueID = ?"
            let params = [
                uniqueID
            ]
            db.execute(sql: sql, params: params)
        }
    }

    private func createLocalFileInfoTable() {
        let tableName = SZAVPlayerLocalFileInfo.tableName
        let sqlQuerys = [
            "CREATE TABLE IF NOT EXISTS \(tableName) (" +
            "id INTEGER PRIMARY KEY ASC, " +
            "uniqueID TEXT, " +
            "startOffset INTEGER, " +
            "loadedByteLength INTEGER, " +
            "localFileName TEXT, " +
            "updated INTEGER" +
            ");\n",
            "CREATE UNIQUE INDEX IF NOT EXISTS \(tableName)_uniqueID_startOffset " +
            "ON \(tableName)(" +
            "uniqueID, startOffset" +
            ");\n",
        ]

        createTable(sqlQuerys: sqlQuerys)
    }

}

// MARK: - Private

private extension SZAVPlayerDatabase {

    func createTable(sqlQuerys: [String]) {
        dbQueue.inTransaction { (db, rollback) in
            for sql in sqlQuerys {
                if db.execute(sql: sql) == SQLITE_RESULT_FAILED {
                    rollback = true
                    break
                }
            }
        }
    }

}
