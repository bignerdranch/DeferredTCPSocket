//
//  ConnectionTableViewCell.swift
//  ChatClient
//
//  Created by John Gallagher on 9/15/14.
//  Copyright (c) 2014 Big Nerd Ranch. All rights reserved.
//

import UIKit

class ConnectionTableViewCell: UITableViewCell {

    @IBOutlet weak var contentLabel: UILabel!

    func setUsername(username: String, connected: Bool) {
        if connected {
            contentLabel.text = "\(username) connected"
        } else {
            contentLabel.text = "\(username) disconnected"
        }
    }
}
