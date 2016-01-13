//
//  DeferredWriter.swift
//  DeferredIO
//
//  Created by John Gallagher on 9/12/14.
//  Copyright (c) 2014 Big Nerd Ranch. All rights reserved.
//

import Foundation
#if os(iOS)
import Deferred
#else
import Deferred
#endif

public final class DeferredWriter {
    private let queue = dispatch_queue_create("DeferredWriter", DISPATCH_QUEUE_SERIAL)
    private let source: dispatch_source_t
    private let timerSource: dispatch_source_t
    private let operationQueue = NSOperationQueue()
    private var closed = false

    public init(fd: Int32, cancelHandler: () -> ()) {
        source = dispatch_source_create(DISPATCH_SOURCE_TYPE_WRITE, UInt(fd), 0, queue)
        dispatch_source_set_cancel_handler(source, cancelHandler)

        timerSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue)

        operationQueue.maxConcurrentOperationCount = 1
    }

    deinit {
//        NSLog("DEINIT: \(self)")
        close(false)
    }

    public func close(force: Bool = true) {
        if !closed {
            if force {
                operationQueue.cancelAllOperations()
            }
            operationQueue.waitUntilAllOperationsAreFinished()

            dispatch_source_cancel(source)
            dispatch_resume(source)

            dispatch_source_cancel(timerSource)
            dispatch_resume(timerSource)

            closed = true
        }
    }

    public func writeData(data: NSData, withTimeout timeout: NSTimeInterval? = nil) -> Deferred<WriteResult> {
        let op = DeferredWriteOperation(data: data, queue: queue, source: source, timerSource: timerSource, timeout: timeout)
        operationQueue.addOperation(op)
        return op.deferred
    }

    public func writeString(string: String, withEncoding encoding: NSStringEncoding = NSUTF8StringEncoding, timeout: NSTimeInterval? = nil) -> Deferred<WriteResult> {
        return writeData(string.dataUsingEncoding(encoding, allowLossyConversion: false)!)
    }
}
