//
//  TCPAcceptSocket.swift
//  DeferredTCPSocket
//
//  Created by John Gallagher on 9/12/14.
//  Copyright (c) 2014 Big Nerd Ranch. All rights reserved.
//

import Foundation
#if os(iOS)
import Result
//import Deferred
//import DeferredIO
#else
import ResultMac
//import DeferredMac
//import DeferredIOMac
#endif

private func socklen_of<T>(x: T) -> socklen_t {
    return socklen_t(sizeof(x.dynamicType))
}

public class TCPAcceptSocket {
    public typealias ConnectionHandler = (queue: dispatch_queue_t, callback: (TCPCommSocket) -> ())

    public struct Error: ErrorType {
        let functionName: String
        let errno: Int32

        public var description: String {
            return "TCPAcceptSocket.Error: \(functionName) failed with errno \(errno)"
        }
    }

    public class func accept(onPort port: UInt16, withConnectionHandler: ConnectionHandler) -> Result<TCPAcceptSocket> {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        if fd < 0 {
            return .Failure(Error(functionName: "socket", errno: errno))
        }

        var addr: UnsafeMutablePointer<addrinfo> = nil
        let cleanupWithError: String -> Result<TCPAcceptSocket> = { functionName in
            let e = errno
            Darwin.close(fd)

            if addr != nil {
                freeaddrinfo(addr)
            }
            return .Failure(Error(functionName: functionName, errno: e))
        }

        var reuseAddr = 1
        if setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuseAddr, socklen_of(reuseAddr)) < 0 {
            return cleanupWithError("setsockopt")
        }

        var hints = addrinfo(
            ai_flags: AI_PASSIVE,
            ai_family: PF_UNSPEC,
            ai_socktype: SOCK_STREAM,
            ai_protocol: IPPROTO_TCP,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil)
        if getaddrinfo(nil, String(port), &hints, &addr) != 0 {
            return cleanupWithError("getaddrinfo")
        }

        if bind(fd, addr.memory.ai_addr, addr.memory.ai_addrlen) != 0 {
            return cleanupWithError("bind")
        }

        if listen(fd, 64) < 0 {
            return cleanupWithError("listen")
        }

        freeaddrinfo(addr)
        let sock = TCPAcceptSocket(fd: fd, withConnectionHandler: withConnectionHandler)
        return .Success(sock)
    }

    private let source: dispatch_source_t
    private let queue = dispatch_queue_create("TCPAcceptSocket", DISPATCH_QUEUE_SERIAL)
    private let connHandler: ConnectionHandler

    public init(fd: Int32, withConnectionHandler connHandler: ConnectionHandler) {
        NSLog("accepting on \(fd)")
        self.source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, UInt(fd), 0, queue)
        self.connHandler = connHandler

        dispatch_source_set_event_handler(source) { [weak self] in
            self?.handlePendingAccept()
            return
        }

        dispatch_source_set_cancel_handler(source) {
            NSLog("closing accept socket \(fd)")
            Darwin.close(fd)
        }
        dispatch_resume(source)
    }

    deinit {
        NSLog("DEINIT \(self)")
        close()
    }

    public func close() {
        dispatch_source_cancel(source)
    }

    private func handlePendingAccept() {
        let numAwaiting = dispatch_source_get_data(source)
        let listening_fd = Int32(dispatch_source_get_handle(source))

        var addr: sockaddr = sockaddr(sa_len: 0, sa_family: 0, sa_data: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
        var len: socklen_t = 0

        for i in 0 ..< numAwaiting {
            let fd = accept(listening_fd, &addr, &len)
            if fd < 0 {
                NSLog("accept() failed: \(errno)")
                continue
            }

            NSLog("accepted fd \(fd)")
            let callback = connHandler.callback
            dispatch_async(connHandler.queue) { callback(TCPCommSocket(fd: fd)) }
        }
    }
}