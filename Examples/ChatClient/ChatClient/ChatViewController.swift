//
//  ChatViewController.swift
//  ChatClient
//
//  Created by John Gallagher on 9/15/14.
//  Copyright (c) 2014 Big Nerd Ranch. All rights reserved.
//

import UIKit
import DeferredTCPSocket
import Deferred
import Result

class ChatViewController: UIViewController, UITextFieldDelegate {
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

        readMessage()
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
        dismissViewControllerAnimated(true, completion: nil)
    }

    func sendMessage(handler: String -> Deferred<WriteResult>) {
        if messageTextField.text.isEmpty {
            return
        }

        handler(messageTextField.text).uponQueue(dispatch_get_main_queue()) { [weak self] result in
            if let error = result.failureValue {
                self?.presentAlertForError(error)
            }
        }

        messageTextField.resignFirstResponder()
        messageTextField.text = ""
    }

    private func readMessage() {
        connection.readMessage().uponQueue(dispatch_get_main_queue()) { [weak self] in
            self?.handleReadMessageResult($0)
            return
        }
    }

    private func handleReadMessageResult(result: Result<Message>) {
        switch result {
        case let .Success(message):
            tableView.insertRowsAtIndexPaths([ messageDataSource.addMessage(message()) ],
                withRowAnimation: .Automatic)
            readMessage()

        case let .Failure(error):
            presentAlertForError(error)
        }
    }

    private func presentAlertForError(error: ErrorType) {
        let alert = UIAlertController(error: error, handler: { [weak self] in
            self?.dismissViewControllerAnimated(true, completion: nil)
            return
        })
        presentViewController(alert, animated: true, completion: nil)
    }
}
