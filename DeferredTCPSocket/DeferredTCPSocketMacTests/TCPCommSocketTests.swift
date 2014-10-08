//
//  TCPCommSocketTests.swift
//  DeferredTCPSocket
//
//  Created by Brian Hardy on 10/8/14.
//  Copyright (c) 2014 Big Nerd Ranch. All rights reserved.
//

import Cocoa
import XCTest

class TCPCommSocketTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testConnectToHost_validHostAndPort() {
        // expect a Deferred filled with .Success(TCPCommSocket)
        XCTFail("not implemented")
    }
    
    func testConnectToHost_invalidHost() {
        // expect a Deferred filled with .Failure(LibCError)
        XCTFail("not implemented")
    }

    func testConnectToHost_invalidPort() {
        // expect a Deferred filled with .Failure(LibCError)
        XCTFail("not implemented")
    }
    
    func testReadData() {
        // expect a Deferred ReadResult
        XCTFail("not implemented")
    }

    func testReadDataWithTimeout() {
        // expect a Deferred ReadResult
        XCTFail("not implemented")
    }

    func testReadDataToLength() {
        // expect a Deferred ReadResult
        XCTFail("not implemented")
    }

    func testReadDataToDelimiter() {
        // expect a Deferred ReadResult
        XCTFail("not implemented")
    }

    func testWriteData() {
        // expect a Deferred ReadResult
        XCTFail("not implemented")
    }

    func testWriteString() {
        // expect a Deferred ReadResult
        XCTFail("not implemented")
    }
}
