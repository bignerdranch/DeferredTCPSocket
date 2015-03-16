//
//  main.swift
//  EchoServer
//
//  Created by John Gallagher on 9/12/14.
//  Copyright (c) 2014 Big Nerd Ranch. All rights reserved.
//

import Cocoa
import DeferredTCPSocketMac

extension ReadError {
    var isTimeout: Bool {
        switch self {
        case .Timeout:
            return true
        case .Eof, .Cancelled, .DelimiterNotFound, .ReadFailedWithErrno:
            return false
        }
    }
}

let ECHO_PORT = UInt16(44444)

func echo(sock: TCPCommSocket) {
    sock.readDataWithTimeout(5).upon { result in
        switch result {
        case let .Success(data):
            sock.writeData(data.value)
            echo(sock)

        case let .Failure(error):
            NSLog("read failed with \(error)")

            // Before disconnecting, notify user if we're killing the connection due to timeout
            if let readError = error as? ReadError {
                if readError.isTimeout {
                    sock.writeString("you took too long - bye\n")
                }
            }
        }
    }
}

let echoHandler = (dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)!, echo)
let accepterResult = TCPAcceptSocket.accept(onPort: ECHO_PORT, withConnectionHandler: echoHandler)

switch accepterResult {
case .Success:
    NSLog("started listening on \(ECHO_PORT)")
    CFRunLoopRun()

case let .Failure(error):
    NSLog("accepter creation failed: \(error)")
}

