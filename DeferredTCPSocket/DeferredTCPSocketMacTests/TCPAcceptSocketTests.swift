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
        XCTFail("not implemented")
    }
    
    func testAccept_portZero() {
        XCTFail("not implemented")
    }
    
    func testConnection() {
        XCTFail("not implemented")
    }
    

}
