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
        // 1. Send our handshake
        return socket.writeString("c:\(username)\n").bind { writeResult in
            resultToDeferred(writeResult) {
                let connection = ChatConnection(socket: socket)

                // 2. Read the response
                return connection.readMessage().map { messageResult in

                    // 3. Confirm that the response is the correct type
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
        }
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