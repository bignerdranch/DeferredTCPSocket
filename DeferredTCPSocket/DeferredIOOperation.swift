//
//  DeferredIOOperation.swift
//  DeferredIO
//
//  Created by John Gallagher on 9/12/14.
//  Copyright (c) 2014 Big Nerd Ranch. All rights reserved.
//

import Foundation

public var DeferredIOOperationLeeway = UInt64(NSEC_PER_SEC / 20)

class DeferredIOOperation: NSOperation {
    let queue: dispatch_queue_t
    let source: dispatch_source_t

    private let timeout: NSTimeInterval?
    private let timerSource: dispatch_source_t

    private var _executing: Bool = false {
        willSet {
            self.willChangeValueForKey("isExecuting")
        }
        didSet {
            self.didChangeValueForKey("isExecuting")
        }
    }

    override var executing: Bool {
        get { return _executing }
        set { _executing = newValue }
    }
    override var asynchronous: Bool { return true }

    init(queue: dispatch_queue_t, source: dispatch_source_t, timerSource: dispatch_source_t, timeout: NSTimeInterval? = nil) {
        self.queue = queue
        self.source = source
        self.timerSource = timerSource
        self.timeout = timeout
        super.init()
    }

    func resumeSources() {
        if let timeout = timeout {
            let when = dispatch_time(DISPATCH_TIME_NOW, Int64(NSTimeInterval(NSEC_PER_SEC)*timeout))
            dispatch_source_set_timer(timerSource, when, 0, DeferredIOOperationLeeway)
            dispatch_source_set_event_handler(timerSource) { [weak self] in
                self?.handleTimeout()
                return
            }
            dispatch_resume(timerSource)
        }

        dispatch_source_set_event_handler(source) { [weak self] in
            self?.handleEvent()
            return
        }
        dispatch_resume(source)
    }

    func suspendSources() {
        if let _ = timeout {
            dispatch_suspend(timerSource)
        }

        dispatch_suspend(source)
    }

    func handleTimeout() {
        assert(false, "subclasses must implement handleTimeout")
    }

    func handleEvent() {
        assert(false, "subclasses must implement handleEvent")
    }

    func willChangeValueForKeyFinished() {
        self.willChangeValueForKey("isFinished")
    }

    func didChangeValueForKeyFinished() {
        self.didChangeValueForKey("isFinished")
    }
}