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
import Result
#else
import DeferredMac
import ResultMac
#endif

public final class TCPCommSocket {
    private let reader: DeferredReader
    private let writer: DeferredWriter

    public class func connectToHost(host: String, serviceOrPort: String) -> Deferred<Result<TCPCommSocket>> {
        let deferred = Deferred<Result<TCPCommSocket>>()

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            var addr: UnsafeMutablePointer<addrinfo> = nil
            var sockfd: Int32 = 0

            let cleanupWithError: String -> () = { functionName in
                let e = errno
                if addr != nil {
                    freeaddrinfo(addr)
                }
                if sockfd > 0 {
                    Darwin.close(sockfd)
                }
                deferred.fill(Result(failure: LibCError(functionName: functionName, errno: e)))
            }

            var hints = addrinfo(
                ai_flags: 0,
                ai_family: AF_INET,
                ai_socktype: SOCK_STREAM,
                ai_protocol: IPPROTO_TCP,
                ai_addrlen: 0,
                ai_canonname: nil,
                ai_addr: nil,
                ai_next: nil)
            if getaddrinfo(host, serviceOrPort, &hints, &addr) != 0 {
                return cleanupWithError("getaddrinfo")
            }

            sockfd = socket(addr.memory.ai_family, addr.memory.ai_socktype, addr.memory.ai_protocol)
            if sockfd < 0 {
                return cleanupWithError("sockfd")
            }

            if connect(sockfd, addr.memory.ai_addr, addr.memory.ai_addrlen) != 0 {
                return cleanupWithError("connect")
            }

            // success!
            let commSocket = TCPCommSocket(fd: sockfd)
            deferred.fill(Result(success: commSocket))
            freeaddrinfo(addr)
        }

        return deferred
    }

    internal init(fd: Int32) {
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

    public func readDataToLength(length: Int, withTimeout timeout: NSTimeInterval? = nil) -> Deferred<ReadResult> {
        return reader.readDataToLength(length, withTimeout: timeout)
    }

    public func readDataToDelimiter(delimiter: NSData, maxLength: Int = Int.max, withTimeout timeout: NSTimeInterval? = nil) -> Deferred<ReadResult> {
        return reader.readDataToDelimiter(delimiter, maxLength: maxLength, withTimeout: timeout)
    }

    public func writeData(data: NSData, withTimeout timeout: NSTimeInterval? = nil) -> Deferred<WriteResult> {
        return writer.writeData(data, withTimeout: timeout)
    }

    public func writeString(string: String, withEncoding encoding: NSStringEncoding = NSUTF8StringEncoding, timeout: NSTimeInterval? = nil) -> Deferred<WriteResult> {
        return writer.writeString(string, withEncoding: encoding, timeout: timeout)
    }
}