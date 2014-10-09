//
//  TCPAcceptSocketTests.swift
//  DeferredTCPSocket
//
//  Created by Brian Hardy on 10/8/14.
//  Copyright (c) 2014 Big Nerd Ranch. All rights reserved.
//

import Cocoa
import XCTest
import DeferredTCPSocketMac
import ResultMac
import DeferredMac

class TCPAcceptSocketTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testAccept_validPort() {
        let connHandler = TCPAcceptSocket.ConnectionHandler(queue: dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), callback: { commSocket in
            // do-nothing
            })
        
        let result = TCPAcceptSocket.accept(onPort: 12345, withConnectionHandler: connHandler)
        XCTAssertNotNil(result.successValue, "Should have a success value")
        if let acceptSocket = result.successValue {
            acceptSocket.close()
        }
    }
    
    func testAccept_portRequiringRoot() {
        let connHandler = TCPAcceptSocket.ConnectionHandler(queue: dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), callback: { commSocket in
            // do-nothing
        })
        
        let result = TCPAcceptSocket.accept(onPort: 1023, withConnectionHandler: connHandler)
        XCTAssertNil(result.successValue, "Should NOT have a success value")
        XCTAssertTrue(result.failureValue is LibCError, "Should have a failure value")
        if let error = result.failureValue as? LibCError {
            XCTAssertEqual(error.functionName, "bind", "Should fail on bind")
            XCTAssertEqual(error.errno, EACCES, "Should fail with EACCES")
        }
    }
    
    func testAccept_portZero() {
        let connHandler = TCPAcceptSocket.ConnectionHandler(queue: dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), callback: { commSocket in
            // do-nothing
        })
        
        let result = TCPAcceptSocket.accept(onPort: 0, withConnectionHandler: connHandler)
        XCTAssertNotNil(result.successValue, "Should have a success value")
        // TODO: This works, but it should give us some way to know what port it used; man getsockname
        if let acceptSocket = result.successValue {
            acceptSocket.close()
        }
    }
    
    func testConnection() {
        
        let connHandler = TCPAcceptSocket.ConnectionHandler(queue: dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), callback: { commSocket in
            // force this to block waiting for the write to finish by calling `value`
            commSocket.writeString("hello").value
            return
        })
        
        let result = TCPAcceptSocket.accept(onPort: 12345, withConnectionHandler: connHandler)
        XCTAssertNotNil(result.successValue, "Should have a success value")
        if let acceptSocket = result.successValue {
            
            // connect to port 12345 using a TCPCommSocket
            let defferedSocketResult = TCPCommSocket.connectToHost("localhost", serviceOrPort: "12345")
            // block waiting for value
            let socketResult = defferedSocketResult.value
            XCTAssertNotNil(socketResult.successValue, "Should have a successful connection")
            if let socket = socketResult.successValue {
                let deferredReadResult = socket.readDataToLength(5)
                // block waiting for value
                let readResult = deferredReadResult.value
                XCTAssertNotNil(readResult.successValue, "Should have a successful data result: \(readResult.failureValue)")
                if let data = readResult.successValue {
                    let readString = NSString(data: data, encoding: NSUTF8StringEncoding)!
                    XCTAssertEqual(readString, "hello", "Should receive 'hello'")
                }
            }
            
            acceptSocket.close()
        }
    }

}
