//
//  TCPCommSocketTests.swift
//  DeferredTCPSocket
//
//  Created by Brian Hardy on 10/8/14.
//  Copyright (c) 2014 Big Nerd Ranch. All rights reserved.
//

import Cocoa
import XCTest
import DeferredTCPSocketMac
import DeferredMac
import ResultMac

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
        // set up a netcat server
        let port = 12346
        let netcat = NSTask()
        netcat.launchPath = "/usr/bin/nc"
        netcat.arguments = ["-l", String(port)]
        
        let outpipe = NSPipe()
        netcat.standardOutput = outpipe
        netcat.launch()
        // oh this is ugly. how else to wait for the task to launch?
        // if we don't wait, we'll get "connection refused" right below
        sleep(1)
        
        let connectExpectation = expectationWithDescription("connectToHost")
        
        // connect to the server on that port and send EOF
        // expect a Deferred to be filled with .Success(TCPCommSocket)
        let deferredResultSocket = TCPCommSocket.connectToHost("localhost", serviceOrPort: String(port))
        deferredResultSocket.upon({
            (resultSocket : Result<TCPCommSocket>) in
            if let socket = resultSocket.successValue {
                // wrap up the EOT char (0x04) as 1-byte NSData
                let eotData = NSData(bytes: [4] as [CChar], length: 1)
                socket.writeData(eotData)
                
                // sleep here to make expectations fail
//                sleep(5)
                
                socket.close()
            } else {
                XCTFail("Could not connect: \(resultSocket.failureValue)")
                netcat.terminate()
            }
            connectExpectation.fulfill()
        })
        
        // wait for expectations
        waitForExpectationsWithTimeout(3, handler: nil)
        
        // wait for netcat to finish
        netcat.waitUntilExit()
        
        XCTAssertEqual(netcat.terminationStatus, Int32(0), "netcat should exit with success")
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
