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
    var isDismissing = false

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var messageTextField: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.estimatedRowHeight = 60;
        tableView.rowHeight = UITableViewAutomaticDimension;
        tableView.sectionHeaderHeight = 0.1;
        tableView.sectionFooterHeight = 0.1;

        connection = ChatConnection(delegate: self, socket: socket, tableView: tableView)
        navigationItem.title = "Connected as \(name)"
        messageTextField.delegate = self
    }

    func textFieldShouldReturn(textField: UITextField) -> Bool {
        sendMessage()
        return true
    }

    @IBAction func sendButtonPressed(sender: AnyObject) {
        sendMessage()
    }

    @IBAction func emoteButtonPressed(sender: AnyObject) {
        connection.sendEmote(messageTextField.text)
        messageTextField.resignFirstResponder()
        messageTextField.text = ""
    }

    @IBAction func doneButtonPressed(sender: AnyObject) {
        isDismissing = true
        socket.close()
        dismissViewControllerAnimated(true, completion: nil)
    }

    func sendMessage() {
        connection.sendMessage(messageTextField.text)

        messageTextField.resignFirstResponder()
        messageTextField.text = ""
    }

    func chatConnection(_: ChatConnection, didFailWithError: ErrorType) {
        if !isDismissing {
            dismissViewControllerAnimated(true, completion: nil)
        }
    }

    func chatConnection(_: ChatConnection, didReceiveErrorMessage message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: { _ in self.dismissViewControllerAnimated(true, completion: nil) }))
        presentViewController(alert, animated: true, completion: nil)
        isDismissing = true
    }
}
