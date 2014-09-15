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

extension TCPCommSocket {
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
    func chatConnection(ChatConnection, didFailWithError: ErrorType)
    func chatConnection(ChatConnection, didReceiveErrorMessage: String)
}

class ChatConnection: NSObject, UITableViewDataSource {
    let socket: TCPCommSocket
    let tableView: UITableView
    var messages = [Message]()
    weak var delegate: ChatConnectionDelegate?

    init(delegate: ChatConnectionDelegate, socket: TCPCommSocket, tableView: UITableView) {
        self.delegate = delegate
        self.socket = socket
        self.tableView = tableView
        super.init()

        tableView.dataSource = self
        tableView.reloadData()
        readMessage()
    }

    func readMessage() {
        socket.readStringToMessageDelimiter().uponQueue(dispatch_get_main_queue()) { [weak self] result in
            if let strelf = self {
                switch result.bind(MessageParser) {
                case let .Success(message):
                    strelf.handleNewMessage(message())

                case let .Failure(error):
                    strelf.delegate?.chatConnection(strelf, didFailWithError: error)
                }
            }
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

    func handleNewMessage(message: Message) {
        switch message {
        case let .Error(error):
            delegate?.chatConnection(self, didReceiveErrorMessage: error)

        case .Connect, .Disconnect, .Emote, .Message:
            messages.insert(message, atIndex: 0)

            let indexPath = NSIndexPath(forRow: 0, inSection: 0)
            tableView.insertRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
            readMessage()
        }
    }

    //MARK: UITableViewDataSource

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let message = messages[indexPath.row]

        switch message {
        case let .Connect(username):
            let cell = tableView.dequeueReusableCellWithIdentifier("ConnectionTableViewCell") as ConnectionTableViewCell
            cell.setUsername(username, connected: true)
            return cell

        case let .Disconnect(username):
            let cell = tableView.dequeueReusableCellWithIdentifier("ConnectionTableViewCell") as ConnectionTableViewCell
            cell.setUsername(username, connected: false)
            return cell

        case let .Message(username: username, contents: contents):
            let cell = tableView.dequeueReusableCellWithIdentifier("MessageTableViewCell") as MessageTableViewCell
            cell.setUsername(username, message: contents)
            return cell

        case let .Emote(username: username, contents: contents):
            let cell = tableView.dequeueReusableCellWithIdentifier("EmoteTableViewCell") as EmoteTableViewCell
            cell.setUsername(username, emote: contents)
            return cell

        case .Error:
            fatalError("Invalid message type to display in table")
        }
    }


}