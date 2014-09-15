//
//  TCPCommSocket.swift
//  DeferredTCPSocket
//
//  Created by John Gallagher on 9/12/14.
//  Copyright (c) 2014 Big Nerd Ranch. All rights reserved.
//

import Foundation
import Darwin
#if os(iOS)
import Deferred
#else
import DeferredMac
#endif

public class TCPCommSocket {
    private let reader: DeferredReader
    private let writer: DeferredWriter

    public init(fd: Int32) {
        let cleanupQueue = dispatch_queue_create("TCPCommSocket.cleanupQueue", DISPATCH_QUEUE_SERIAL)

        if fcntl_set_O_NONBLOCK(fd) < 0 {
            NSLog("Could not set O_NONBLOCK on fd \(fd)")
        }

        // TODO: comment this (see netcat.c)
        dispatch_suspend(cleanupQueue)
        dispatch_suspend(cleanupQueue)
        dispatch_async(cleanupQueue) {
            NSLog("cleanupQueue: closing fd \(fd)")
            Darwin.close(fd)
        }

        let cancelHandler: () -> () = { dispatch_resume(cleanupQueue) }
        reader = DeferredReader(fd: fd, cancelHandler: cancelHandler)
        writer = DeferredWriter(fd: fd, cancelHandler: cancelHandler)
    }

    deinit {
//        NSLog("DEINIT \(self)")
        close()
    }

    public func close() {
        reader.close()
        writer.close()
    }

    public func readData() -> Deferred<ReadResult> {
        return reader.readData()
    }

    public func readDataWithTimeout(timeout: NSTimeInterval) -> Deferred<ReadResult> {
        return reader.readDataWithTimeout(timeout)
    }

    public func readDataToLength(length: UInt, withTimeout timeout: NSTimeInterval? = nil) -> Deferred<ReadResult> {
        return reader.readDataToLength(length, withTimeout: timeout)
    }

    public func readDataToDelimiter(delimiter: NSData, maxLength: UInt = UInt.max, withTimeout timeout: NSTimeInterval? = nil) -> Deferred<ReadResult> {
        return reader.readDataToDelimiter(delimiter, maxLength: maxLength, withTimeout: timeout)
    }

    public func writeData(data: NSData, withTimeout timeout: NSTimeInterval? = nil) -> Deferred<WriteResult> {
        return writer.writeData(data, withTimeout: timeout)
    }

    public func writeString(string: String, withEncoding encoding: NSStringEncoding = NSUTF8StringEncoding, timeout: NSTimeInterval? = nil) -> Deferred<WriteResult> {
        return writer.writeString(string, withEncoding: encoding, timeout: timeout)
    }
}