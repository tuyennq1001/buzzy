import Foundation
import SwiftUI

protocol BuzzyLogEvent: Encodable {
    var type: String { get }
    var timestamp: Date { get }
}

class BuzzyLogEventAppStart: BuzzyLogEvent {
    internal let type = "appstart"
    internal let timestamp: Date = Date()
}

class BuzzyLogEventTransition: BuzzyLogEvent {
    internal let type = "transition"
    internal let timestamp: Date = Date()

    private let event: String
    private let fromState: String
    private let toState: String

    init(fromContext ctx: BuzzyStateMachine.Context) {
        event = "\(ctx.event!)"
        fromState = "\(ctx.fromState)"
        toState = "\(ctx.toState)"
    }
}

private let logFileName = "Buzzy.log"
private let lineEnd = "\n".data(using: .utf8)!

internal let logger = BuzzyLogger()

class BuzzyLogger {
    private let logHandle: FileHandle?
    private let encoder = JSONEncoder()

    init() {
        encoder.outputFormatting = .sortedKeys
        encoder.dateEncodingStrategy = .secondsSince1970

        let fileManager = FileManager.default
        let logPath = fileManager
            .urls(for: .cachesDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent(logFileName)
            .path

        if !fileManager.fileExists(atPath: logPath) {
            guard fileManager.createFile(atPath: logPath, contents: nil) else {
                print("Failed to create \(logPath)")
                logHandle = nil
                return
            }
        }

        do {
            logHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: logPath))
            logHandle?.seekToEndOfFile()
        } catch {
            print("Failed to open \(logPath): \(error)")
            logHandle = nil
        }
    }

    func append(event: BuzzyLogEvent) {
        guard let logHandle = logHandle else {
            return
        }
        do {
            let data = try encoder.encode(event)
            logHandle.write(data)
            logHandle.write(lineEnd)
        } catch {
            print("Failed to write to \(logFileName): \(error)")
        }
    }
}
