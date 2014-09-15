//
//  MessageTableViewCell.swift
//  ChatClient
//
//  Created by John Gallagher on 9/15/14.
//  Copyright (c) 2014 Big Nerd Ranch. All rights reserved.
//

import UIKit

class MessageTableViewCell: UITableViewCell {

    @IBOutlet weak var usernameLabel: UILabel!
    @IBOutlet weak var messageLabel: UILabel!

    func setUsername(username: String, message: String) {
        usernameLabel.text = "\(username):"
        messageLabel.text = message
    }
}
