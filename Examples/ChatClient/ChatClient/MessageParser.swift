//
//  MessageParser.swift
//  ChatClient
//
//  Created by John Gallagher on 9/15/14.
//  Copyright (c) 2014 Big Nerd Ranch. All rights reserved.
//

import Foundation
import Result

struct InvalidMessageError: ErrorType {
    var description: String {
        return "Invalid message"
    }
}

enum Message {
    case Connect(String)
    case Disconnect(String)
    case Emote(username: String, contents: String)
    case Message(username: String, contents: String)
}

struct ServerError: ErrorType {
    let description: String

    init(description: String) {
        self.description = description
    }
}

private func createParser<T>(prefix: String, toResult: String -> Result<T>) -> String -> Result<T>? {
    return { str in
        NSLog("trying to parse \(str) for \(prefix)")
        if startsWith(str, prefix) {
            let contents = str[advance(str.startIndex, countElements(prefix)) ..< str.endIndex]
            if contents.isEmpty {
                return .Failure(InvalidMessageError())
            } else {
                return toResult(contents)
            }
        } else {
            return nil
        }
    }
}

private func parseUsernameAndContents(input: String) -> Result<(username: String, contents: String)> {
    let splitInput = split(input, { $0 == ":" }, maxSplit: 1, allowEmptySlices: false)
    if splitInput.count == 2 {
        return .Success((username: splitInput[0], contents: splitInput[1]))
    } else {
        return .Failure(InvalidMessageError())
    }
}

private let MessageParsers: [String -> Result<Message>?] = [
    // NOTE: These parsers are tried in order, and a successful parse prevents
    // later parsers from being called. Order these with the most common
    // message types first.
    createParser("m:", { parseUsernameAndContents($0).map { .Message($0) } }),
    createParser("e:", { parseUsernameAndContents($0).map { .Emote($0) } }),
    createParser("c:", { username in .Success(.Connect(username)) }),
    createParser("d:", { username in .Success(.Disconnect(username)) }),
    createParser("x:", { error in .Failure(ServerError(description: error)) }),
]

func MessageParser(str: String) -> Result<Message> {
    // lazily call the parsers, and the first time one returns an Ok result, return that result
    if let result = first(lazy(MessageParsers).map({ parser in parser(str) }).filter({ $0 != nil })) {
        return result!
    }
    // no parsers returned ok - must be invalid
    return .Failure(InvalidMessageError())
}