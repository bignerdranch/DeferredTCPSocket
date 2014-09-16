//
//  ChatConnection.swift
//  ChatClient
//
//  Created by John Gallagher on 9/15/14.
//  Copyright (c) 2014 Big Nerd Ranch. All rights reserved.
//

import Foundation
import Result
import Deferred
import DeferredTCPSocket

private let MessageDelimiterCharacter: Character = "\n"
private let MessageDelimiter = String(MessageDelimiterCharacter).dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
private let MaxMessageLength = UInt(16384)

private extension TCPCommSocket {
    func readStringToMessageDelimiter() -> Deferred<Result<String>> {
        return self.readDataToDelimiter(MessageDelimiter, maxLength: MaxMessageLength).map {
            readResult in

            switch readResult {
            case let .Success(data):
                let utf8String: NSString? = NSString(data: data(), encoding: NSUTF8StringEncoding)
                if let s: String = utf8String {
                    return .Success(s)
                } else {
                    NSLog("Received non-UTF8 data; ignoring message")
                    return .Failure(InvalidMessageError())
                }

            case let .Failure(error):
                return .Failure(error)
            }
        }
    }
}

protocol ChatConnectionDelegate: class {
    func chatConnection(ChatConnection, didReceiveMessage: Message)
    func chatConnection(ChatConnection, didFailWithError: ErrorType)
}

class ChatConnection: NSObject {
    private let socket: TCPCommSocket

    class func handshakeOverSocket(username: String, socket: TCPCommSocket) -> Deferred<Result<ChatConnection>> {
        return socket.writeString("c:\(username)\n").map { writeResult in
            writeResult.map {
                ChatConnection(socket: socket)
            }
        }
    }

    init(socket: TCPCommSocket) {
        self.socket = socket
        super.init()
    }

    func close() {
        socket.close()
    }

    func readMessage() -> Deferred<Result<Message>> {
        return socket.readStringToMessageDelimiter().map { $0.bind(MessageParser) }
    }

    func sendMessage(message: String) -> Deferred<WriteResult> {
        return sendString("m:\(message)\n")
    }

    func sendEmote(message: String) -> Deferred<WriteResult> {
        return sendString("e:\(message)\n")
    }

    private func sendString(s: String) -> Deferred<WriteResult> {
        return socket.writeString(s)
    }
}