//
//  WriteOperations.swift
//  DeferredIO
//
//  Created by John Gallagher on 9/12/14.
//  Copyright (c) 2014 Big Nerd Ranch. All rights reserved.
//

import Foundation
#if os(iOS)
import Deferred
import Result
#else
import DeferredMac
import ResultMac
#endif

public enum WriteError: ErrorType {
    case Cancelled
    case Timeout
    case WriteFailedWithErrno(Int32)

    public var description: String {
        switch (self) {
        case Cancelled: return "WriteError.Cancelled"
        case Timeout: return "WriteError.Timeout"
        case WriteFailedWithErrno(let errno): return "WriteError.ReadFailedWithErrno(\(errno))"
        }
    }
}

public typealias WriteResult = Result<Void>

class DeferredWriteOperation: DeferredIOOperation {
    let deferred = Deferred<WriteResult>()
    let data: NSData
    var written = 0

    override var finished: Bool { return deferred.isFilled }

    init(data: NSData, queue: dispatch_queue_t, source: dispatch_source_t, timerSource: dispatch_source_t, timeout: NSTimeInterval? = nil) {
        self.data = data
        super.init(queue: queue, source: source, timerSource: timerSource, timeout: timeout)
    }

    deinit {
//        NSLog("DEINIT \(self)")
    }

    func complete(result: WriteResult) {
        if executing {
            suspendSources()
            executing = false
        }

        self.willChangeValueForKeyFinished()
        deferred.fill(result)
        self.didChangeValueForKeyFinished()
    }

    override func cancel() {
        super.cancel()
        dispatch_async(queue) { [weak self] in
            if let s = self {
                if s.executing {
                    s.complete(Result(failure: WriteError.Cancelled))
                }
            }
        }
    }

    override func handleTimeout() {
        complete(Result(failure: WriteError.Timeout))
    }

    override func start() {
        dispatch_sync(queue) {
            self.realStart()
        }
    }

    private func realStart() {
        if self.cancelled {
            complete(Result(failure: WriteError.Cancelled))
            return
        }

        if !finished {
            executing = true

            resumeSources()
        }
    }

    override func handleEvent() {
        let fd = Int32(dispatch_source_get_handle(source))
        let remaining = data.length - written

        let actualWritten = write(fd, advance(data.bytes, written), remaining)

        if actualWritten > 0 {
            written += actualWritten
            if written == data.length {
                complete(Result(success: ()))
            }
        } else {
            complete(Result(failure: WriteError.WriteFailedWithErrno(errno)))
        }
    }
}