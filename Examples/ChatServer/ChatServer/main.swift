//
//  main.swift
//  ChatServer
//
//  Created by John Gallagher on 9/12/14.
//  Copyright (c) 2014 Big Nerd Ranch. All rights reserved.
//

import Cocoa
import DeferredTCPSocketMac

let ListenPort = UInt16(13579)

let server = ChatServer()

let accept = TCPAcceptSocket.accept(onPort: ListenPort,
    withConnectionHandler: (dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), server.handleConnection))

switch accept {
case .Success:
    NSLog("Now listening on \(ListenPort)")
    CFRunLoopRun()

case let .Failure(error):
    NSLog("failed to start server: \(error)")
}

