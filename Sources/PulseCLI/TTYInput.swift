//
//  TTYInput.swift
//  PulseCLI
//
//  Lightweight raw-key terminal input helpers for modern TTY interactions.
//  Gracefully falls back to line-based input when raw mode is unavailable.
//

import Foundation
import Darwin

enum TTYInput {
    static var isInteractiveTTY: Bool {
        isatty(STDIN_FILENO) != 0 && isatty(STDOUT_FILENO) != 0
    }

    @discardableResult
    static func withRawMode<T>(_ body: () throws -> T) rethrows -> T? {
        guard isInteractiveTTY else { return nil }

        var original = termios()
        guard tcgetattr(STDIN_FILENO, &original) == 0 else { return nil }

        var raw = original
        raw.c_lflag &= ~tcflag_t(ICANON | ECHO)
        withUnsafeMutableBytes(of: &raw.c_cc) { bytes in
            bytes[Int(VMIN)] = 1
            bytes[Int(VTIME)] = 0
        }

        guard tcsetattr(STDIN_FILENO, TCSANOW, &raw) == 0 else { return nil }
        defer {
            var restore = original
            tcsetattr(STDIN_FILENO, TCSANOW, &restore)
        }

        return try body()
    }

    static func readKey() -> String? {
        if let key = withRawMode({ () -> String in
            var byte: UInt8 = 0
            let count = read(STDIN_FILENO, &byte, 1)
            if count == 1 {
                switch byte {
                case 13, 10: return "enter"
                case 27: return "escape"
                default: return String(UnicodeScalar(byte))
                }
            }
            return ""
        }) {
            print()
            fflush(stdout)
            return key.isEmpty ? nil : key.lowercased()
        }

        let line = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let line, line.isEmpty { return "enter" }
        return line
    }
}
