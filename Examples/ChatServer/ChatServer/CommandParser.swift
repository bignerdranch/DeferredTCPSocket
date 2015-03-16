//
//  CommandParser.swift
//  ChatServer
//
//  Created by John Gallagher on 9/12/14.
//  Copyright (c) 2014 Big Nerd Ranch. All rights reserved.
//

import Foundation
import ResultMac

struct InvalidCommandError: ErrorType {
    var description: String {
        return "Invalid command"
    }
}

struct Handshake: Printable {
    let username: String

    var description: String {
        return "Handshake(\(username)"
    }
}

enum Command: Printable {
    case Emote(String)
    case Message(String)

    var description: String {
        switch self {
        case .Emote(let emote): return "Emote(\(emote))"
        case .Message(let message): return "Message(\(message))"
        }
    }
}

private func createParser<T>(prefix: String, toResult: String -> T) -> String -> Result<T> {
    return { str in
        NSLog("trying to parse \(str) for \(prefix)")
        if startsWith(str, prefix) {
            let contents = str[advance(str.startIndex, countElements(prefix)) ..< str.endIndex]
            if contents.isEmpty {
                return .Failure(InvalidCommandError())
            } else {
                let result = toResult(contents)
                return Result(success: result)
            }
        } else {
            return .Failure(InvalidCommandError())
        }
    }
}

let HandshakeParser = createParser("c:", { Handshake(username: $0) })

private let CommandParsers: [String -> Result<Command>] = [
    // NOTE: These parsers are tried in order, and a successful parse prevents
    // later parsers from being called. Order these with the most common
    // command types first.
    createParser("m:", { .Message($0) }),
    createParser("e:",   { .Emote($0) }),
]

func CommandParser(str: String) -> Result<Command> {
    // lazily call the parsers, and the first time one returns an Ok result, return that result
    if let result = first(lazy(CommandParsers).map({ parser in parser(str) }).filter({ result in result.isSuccess })) {
        return result
    }
    // no parsers returned ok - must be invalid
    return .Failure(InvalidCommandError())
}