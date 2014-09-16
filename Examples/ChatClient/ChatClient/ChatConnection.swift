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
    let socket: TCPCommSocket
    weak var delegate: ChatConnectionDelegate?

    init(socket: TCPCommSocket) {
        self.socket = socket
        super.init()
    }

    func close() {
        delegate = nil
        socket.close()
    }

    func readMessage() {
        socket.readStringToMessageDelimiter().uponQueue(dispatch_get_main_queue()) { [weak self] result in
            self?.handleIncomingMessage(result.bind(MessageParser))
            return
        }
    }

    private func handleIncomingMessage(result: Result<Message>) {
        switch result {
        case let .Success(message):
            self.delegate?.chatConnection(self, didReceiveMessage: message())

        case let .Failure(error):
            self.delegate?.chatConnection(self, didFailWithError: error)
        }
    }

    func sendMessage(message: String) {
        if !message.isEmpty {
            sendString("m:\(message)\n")
        }
    }

    func sendEmote(message: String) {
        if !message.isEmpty {
            sendString("e:\(message)\n")
        }
    }

    private func sendString(s: String) {
        socket.writeString(s, withEncoding: NSUTF8StringEncoding).uponQueue(dispatch_get_main_queue()) { [weak self] in
            if let strelf = self {
                if let error = $0.failureValue {
                    strelf.delegate?.chatConnection(strelf, didFailWithError: error)
                }
            }
        }
    }
}