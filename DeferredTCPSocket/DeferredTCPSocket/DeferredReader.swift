//
//  DeferredReader.swift
//  DeferredIO
//
//  Created by John Gallagher on 9/12/14.
//  Copyright (c) 2014 Big Nerd Ranch. All rights reserved.
//

import Foundation
#if os(iOS)
import Deferred
#else
import DeferredMac
#endif

public class DeferredReader: ReadOperationDelegate {
    private let queue = dispatch_queue_create("DeferredReader", DISPATCH_QUEUE_SERIAL)
    private let source: dispatch_source_t
    private let timerSource: dispatch_source_t
    private let operationQueue = NSOperationQueue()
    private var closed = false

    public init(fd: Int32, cancelHandler: () -> ()) {
        source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, UInt(fd), 0, queue)
        dispatch_source_set_cancel_handler(source, cancelHandler)

        timerSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue)

        operationQueue.maxConcurrentOperationCount = 1
    }

    deinit {
        NSLog("DEINIT: \(self)")
        close()
    }

    public func close() {
        if !closed {
            operationQueue.cancelAllOperations()

            dispatch_source_cancel(source)
            dispatch_resume(source)

            dispatch_source_cancel(timerSource)
            dispatch_resume(timerSource)

            closed = true
        }
    }

    public func readData() -> Deferred<ReadResult> {
        return enqueueOperation(ReadLengthOperation(delegate: self, queue: queue, source: source, timerSource: timerSource, minLength: 1))
    }

    public func readDataWithTimeout(timeout: NSTimeInterval) -> Deferred<ReadResult> {
        return enqueueOperation(ReadLengthOperation(delegate: self, queue: queue, source: source, timerSource: timerSource, minLength: 1, timeout: timeout))
    }

    public func readDataToLength(length: UInt, withTimeout timeout: NSTimeInterval? = nil) -> Deferred<ReadResult> {
        return enqueueOperation(ReadLengthOperation(delegate: self, queue: queue, source: source, timerSource: timerSource, minLength: length, maxLength: length, timeout: timeout))
    }

    public func readDataToDelimiter(delimiter: NSData, maxLength: UInt = UInt.max, withTimeout timeout: NSTimeInterval? = nil) -> Deferred<ReadResult> {
        return enqueueOperation(ReadDelimiterOperation(delegate: self, queue: queue, source: source, timerSource: timerSource, delimiter: delimiter, maxLength: maxLength, timeout: timeout))
    }

    private func enqueueOperation(op: DeferredReadOperation) -> Deferred<ReadResult> {
        operationQueue.addOperation(op)
        return op.deferred
    }

    //MARK: ReadOperationDelegate
    var bufferedData: dispatch_data_t = get_dispatch_data_empty()
}
