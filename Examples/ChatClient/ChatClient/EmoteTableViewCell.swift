//
//  EmoteTableViewCell.swift
//  ChatClient
//
//  Created by John Gallagher on 9/15/14.
//  Copyright (c) 2014 Big Nerd Ranch. All rights reserved.
//

import UIKit

class EmoteTableViewCell: UITableViewCell {

    @IBOutlet weak var contentsLabel: UILabel!

    func setUsername(username: String, emote: String) {
        contentsLabel.text = "\(username) \(emote)"
    }
}
