//
//  ChatViewController.swift
//  ChatClient
//
//  Created by John Gallagher on 9/15/14.
//  Copyright (c) 2014 Big Nerd Ranch. All rights reserved.
//

import UIKit
import DeferredTCPSocket
import Result

class ChatViewController: UIViewController, UITextFieldDelegate, ChatConnectionDelegate {
    var socket: TCPCommSocket!
    var name: String!
    var connection: ChatConnection!

    let messageDataSource = MessageTableViewDataSource()

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var messageTextField: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.estimatedRowHeight = 60;
        tableView.rowHeight = UITableViewAutomaticDimension;
        tableView.sectionHeaderHeight = 0.1;
        tableView.sectionFooterHeight = 0.1;
        tableView.dataSource = messageDataSource

        navigationItem.title = "Connected as \(name)"
        messageTextField.delegate = self

        connection = ChatConnection(socket: socket)
        connection.delegate = self
        connection.readMessage()
    }

    func textFieldShouldReturn(textField: UITextField) -> Bool {
        sendMessage(connection.sendMessage)
        return true
    }

    @IBAction func sendButtonPressed(sender: AnyObject) {
        sendMessage(connection.sendMessage)
    }

    @IBAction func emoteButtonPressed(sender: AnyObject) {
        sendMessage(connection.sendEmote)
    }

    @IBAction func doneButtonPressed(sender: AnyObject) {
        connection.close()
        dismissViewControllerAnimated(true, completion: nil)
    }

    func sendMessage(handler: String -> Void) {
        handler(messageTextField.text)

        messageTextField.resignFirstResponder()
        messageTextField.text = ""
    }

    func chatConnection(connection: ChatConnection, didReceiveMessage message: Message) {
        tableView.insertRowsAtIndexPaths([ messageDataSource.addMessage(message) ],
            withRowAnimation: .Automatic)
        connection.readMessage()
    }

    func chatConnection(_: ChatConnection, didFailWithError error: ErrorType) {
        let alert = UIAlertController(error: error, handler: { [weak self] in
            self?.dismissViewControllerAnimated(true, completion: nil)
            return
        })
        presentViewController(alert, animated: true, completion: nil)
    }
}
