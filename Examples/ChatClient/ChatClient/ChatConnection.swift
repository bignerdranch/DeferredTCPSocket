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

            readResult.bind { data in
                if let utf8String = NSString(data: data, encoding: NSUTF8StringEncoding) {
                    return .Success(utf8String)
                } else {
                    NSLog("Received non-UTF8 data; ignoring message")
                    return .Failure(InvalidMessageError())
                }
            }
        }
    }
}

protocol ChatConnectionDelegate: class {
    func chatConnection(ChatConnection, didReceiveMessage: Message)
    func chatConnection(ChatConnection, didFailWithError: ErrorType)
}

class ChatConnection {
    private let socket: TCPCommSocket

    class func handshakeOverSocket(username: String, socket: TCPCommSocket) -> Deferred<Result<ChatConnection>> {
        let connection = ChatConnection(socket: socket)

        // After we connect, we should immediately get back a Connect message on success.
        // This closure confirms that we do, and returns the connection if so.
        let confirmResponse: () -> Deferred<Result<ChatConnection>> = {
            connection.readMessage().map { messageResult in
                messageResult.bind { message in
                    switch message {
                    case .Connect:
                        return .Success(connection)

                    case .Disconnect, .Emote, .Message:
                        return .Failure(ServerError(description: "Unexpected handshake response from server"))
                    }
                }
            }
        }

        return socket.writeString("c:\(username)\n").bind { resultToDeferred($0, confirmResponse) }
    }

    init(socket: TCPCommSocket) {
        self.socket = socket
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