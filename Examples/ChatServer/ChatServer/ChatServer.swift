//
//  ChatServer.swift
//  ChatServer
//
//  Created by John Gallagher on 9/12/14.
//  Copyright (c) 2014 Big Nerd Ranch. All rights reserved.
//

import Foundation
import ResultMac
import DeferredMac
import DeferredTCPSocketMac

private let CommandDelimiter = "\n".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
private let HandshakeTimeout = NSTimeInterval(10)
private let CommandTimeout = NSTimeInterval(120)
private let MaxCommandLength = UInt(16384)

extension TCPCommSocket {
    func readStringToCommandDelimiter() -> Deferred<Result<String>> {
        return self.readDataToDelimiter(CommandDelimiter, maxLength: MaxCommandLength, withTimeout: CommandTimeout).map {
            readResult in

            readResult.bind { data in
                if let utf8String = NSString(data: data, encoding: NSUTF8StringEncoding) {
                    return Result(success: utf8String)
                } else {
                    NSLog("Received non-UTF8 data; ignoring command")
                    return .Failure(InvalidCommandError())
                }
            }
        }
    }
}

class ChatServer {
    private struct Client {
        let sock: TCPCommSocket
        let username: String

        func writeString(s: String) -> Deferred<WriteResult> {
            return sock.writeString(s, timeout: CommandTimeout)
        }
    }

    private let queue = dispatch_queue_create("ChatServer.queue", DISPATCH_QUEUE_SERIAL)
    private var clients = [String:Client]()

    init() {
        let address = unsafeAddressOf(self)
        dispatch_queue_set_specific(queue, address, UnsafeMutablePointer(address), nil)
    }

    func handleConnection(sock: TCPCommSocket) {
        sock.readStringToCommandDelimiter().uponQueue(queue) { result in
            switch result.bind(HandshakeParser) {
            case let .Success(handshake):
                let client = Client(sock: sock, username: handshake.value.username)
                self.addNewClient(client)

            case let .Failure(error):
                NSLog("handshake failed: \(error)")
            }
        }
    }

    private func addNewClient(client: Client) {
        assertOnPrivateQueue()
        if clients[client.username] != nil {
            client.writeString("x:Username is taken. Bye.\n").upon { _ in client.sock.close() }
            return
        }
        if contains(client.username, ":") {
            client.writeString("x:Invalid username. Bye.\n").upon { _ in client.sock.close() }
            return
        }

        clients[client.username] = client
        broadcast("c:\(client.username)\n")
        readCommandFromClient(client)
    }

    private func removeClient(client: Client) {
        assertOnPrivateQueue()
        clients.removeValueForKey(client.username)
        broadcast("d:\(client.username)\n")
    }

    private func readCommandFromClient(client: Client) {
        client.sock.readStringToCommandDelimiter().uponQueue(queue) { result in
            switch result.bind(CommandParser) {
            case let .Success(command):
                self.handleCommand(command.value, fromClient: client)
                self.readCommandFromClient(client)

            case let .Failure(error):
                var shouldRemoveImmediately = true
                if let readError = error as? ReadError {
                    if readError == .Timeout {
                        client.writeString("x:Idle for too long. Bye!\n").uponQueue(self.queue, { _ in self.removeClient(client) })
                        shouldRemoveImmediately = false
                    }
                }

                if shouldRemoveImmediately {
                    NSLog("Error reading from \(client.username) (\(error)) - disconnecting them")
                    self.removeClient(client)
                }
            }
        }
    }

    private func handleCommand(command: Command, fromClient client: Client) {
        assertOnPrivateQueue()
        switch command {
        case let .Message(message):
            broadcast("m:\(client.username):\(message)\n")

        case let .Emote(emote):
            broadcast("e:\(client.username):\(emote)\n")
        }
    }

    private func broadcast(message: String) {
        assertOnPrivateQueue()
        for client in clients.values {
            client.writeString(message).uponQueue(queue) { result in
                switch result {
                case .Success:
                    break

                case let .Failure(error):
                    NSLog("Error writing to client \(client.username) (\(error)) - disconnecting them")
                    self.removeClient(client)
                }
            }
        }
    }

    private func assertOnPrivateQueue() {
        let address = unsafeAddressOf(self)
        assert(dispatch_get_specific(address) == address, "called on incorrect queue")
    }
}