//
//  MessageTableViewDataSource.swift
//  ChatClient
//
//  Created by John Gallagher on 9/15/14.
//  Copyright (c) 2014 Big Nerd Ranch. All rights reserved.
//

import UIKit

class MessageTableViewDataSource: NSObject, UITableViewDataSource {
    var messages = [Message]()

    func addMessage(message: Message) -> NSIndexPath {
        messages.insert(message, atIndex: 0)
        return NSIndexPath(forRow: 0, inSection: 0)
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
        }
    }
}
