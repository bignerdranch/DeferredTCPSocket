//
//  Support.swift
//  ChatServer
//
//  Created by John Gallagher on 9/12/14.
//  Copyright (c) 2014 Big Nerd Ranch. All rights reserved.
//

import Foundation

func first<S: SequenceType>(sequence: S) -> S.Generator.Element? {
    var generator = sequence.generate()
    return generator.next()
}