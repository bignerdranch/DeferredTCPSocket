//
//  ViewController.swift
//  ChatClient
//
//  Created by John Gallagher on 9/15/14.
//  Copyright (c) 2014 Big Nerd Ranch. All rights reserved.
//

import UIKit
import DeferredTCPSocket
import Deferred
import Result

extension NSUserDefaults {
    var host: String? {
        get {
            return self.stringForKey("host")
        }
        set {
            self.setObject(newValue, forKey: "host")
        }
    }

    var username: String? {
        get {
            return self.stringForKey("username")
        }
        set {
            self.setObject(newValue, forKey: "username")
        }
    }
}

class ConnectViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var serverTextField: UITextField!
    @IBOutlet weak var chatNameTextField: UITextField!
    @IBOutlet weak var connectButton: UIButton!

    let userDefaults = NSUserDefaults.standardUserDefaults()

    var connecting: Bool = false {
        didSet {
            serverTextField.enabled = !connecting
            chatNameTextField.enabled = !connecting
            connectButton.enabled = !connecting
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        serverTextField.text = userDefaults.host ?? ""
        chatNameTextField.text = userDefaults.username ?? ""
    }

    @IBAction func connectButtonPressed(sender: AnyObject) {
        connectToChatServer()
    }

    func connectToChatServer() {
        let host = serverTextField.text
        let name = chatNameTextField.text
        connecting = true

        let deferredSocket = TCPCommSocket.connectToHost(serverTextField.text, serviceOrPort: "13579")

        let handshakeResult: Deferred<WriteResult> = deferredSocket.map { socketResult in
            socketResult.bind { socket -> WriteResult in
                socket.writeString("c:\(name)\n", withEncoding: NSUTF8StringEncoding).value
            }
        }

        handshakeResult.uponQueue(dispatch_get_main_queue()) { result in
            self.connecting = false

            switch result {
            case .Success:
                self.presentChatViewControllerWithSocket(deferredSocket.value.successValue!, name: name)
                self.userDefaults.host = host
                self.userDefaults.username = name

            case let .Failure(error):
                NSLog("Connection failed: \(error)")
            }
        }
    }

    func sendChatName(socket: TCPCommSocket) -> Deferred<WriteResult> {
        return socket.writeString("c:\(chatNameTextField.text)", withEncoding: NSUTF8StringEncoding)
    }

    func presentChatViewControllerWithSocket(socket: TCPCommSocket, name: String) {
        let chatNavigationVC = storyboard?.instantiateViewControllerWithIdentifier("ChatViewController") as? UINavigationController
        if let chatVC = chatNavigationVC?.viewControllers.first as? ChatViewController {
            chatVC.socket = socket
            chatVC.name = name
            showViewController(chatNavigationVC!, sender: self)
        }
    }
}

