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
import Swiftz
import Deferred

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
        XCTAssertNotNil(result.right, "Should have a success value")
        if let acceptSocket = result.right {
            acceptSocket.close()
        }
    }
    
    func testAccept_portRequiringRoot() {
        let connHandler = TCPAcceptSocket.ConnectionHandler(queue: dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), callback: { commSocket in
            // do-nothing
        })
        
        let result = TCPAcceptSocket.accept(onPort: 1023, withConnectionHandler: connHandler)
        XCTAssertNil(result.right, "Should NOT have a success value")
        XCTAssertTrue(result.left is LibCError, "Should have a failure value")
        if let error = result.left as? LibCError {
            XCTAssertEqual(error.functionName, "bind", "Should fail on bind")
            XCTAssertEqual(error.errno, EACCES, "Should fail with EACCES")
        }
    }
    
    func testAccept_portZero() {
        let connExpectation = expectationWithDescription("accepted on a random port")
        let connHandler = TCPAcceptSocket.ConnectionHandler(queue: dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), callback: { commSocket in
            connExpectation.fulfill()
        })
        
        let result = TCPAcceptSocket.accept(onPort: 0, withConnectionHandler: connHandler)
        XCTAssertNotNil(result.right, "Should have a success value")

        if let acceptSocket = result.right {
            // make sure we got a non-zero port
            XCTAssertNotEqual(acceptSocket.port, UInt16(0))

            // connect to make sure the port is correct
            let client = TCPCommSocket.connectToHost("localhost", serviceOrPort: String(acceptSocket.port))
            client.upon { XCTAssertNotNil($0.right) }

            waitForExpectationsWithTimeout(3.0, handler: nil)
            acceptSocket.close()
        }
    }
    
    func testConnection() {
        let readyExpectation = expectationWithDescription("ready")
        
        let connHandler = TCPAcceptSocket.ConnectionHandler(queue: dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), callback: { commSocket in
            // force this to block waiting for the write to finish by calling `value`
            commSocket.writeString("hello").upon{result in
                //let c = commSocket
                XCTAssertNotNil(result.right, "Write should be successful \(result.left)")
            }
            return
        })
        
        let result = TCPAcceptSocket.accept(onPort: 12345, withConnectionHandler: connHandler)
        XCTAssertNotNil(result.right, "Should have a success value \(result.left)")
        if let acceptSocket = result.right {
            // connect to port 12345 using a TCPCommSocket
            let defferedSocketResult = TCPCommSocket.connectToHost("localhost", serviceOrPort: "12345")
            // block waiting for value
            defferedSocketResult.upon {socketResult in
                XCTAssertNotNil(socketResult.right, "Should have a successful connection")
                if let socket = socketResult.right {
                    sleep(1)
                    let deferredReadResult = socket.readDataToLength(5, withTimeout: 1.0)
                    // block waiting for value
                    deferredReadResult.upon {readResult in
                        XCTAssertNotNil(readResult.right, "Should have a successful data result: \(readResult.left)")
                        if let data = readResult.right {
                            let readString = NSString(data: data, encoding: NSUTF8StringEncoding)!
                            XCTAssertEqual(readString, "hello", "Should receive 'hello'")
                        }
                        readyExpectation.fulfill()
                    }
                }
                
            }
            waitForExpectationsWithTimeout(3.0, handler: nil)
            acceptSocket.close()
        }
    }

}
