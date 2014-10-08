//
//  ReadOperations.swift
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

public enum ReadError: ErrorType, Equatable {
    case Eof
    case Cancelled
    case Timeout
    case DelimiterNotFound
    case ReadFailedWithErrno(Int32)

    public var description: String {
        switch self {
        case Eof: return "ReadError.Eof"
        case Cancelled: return "ReadError.Cancelled"
        case Timeout: return "ReadError.Timeout"
        case DelimiterNotFound: return "ReadError.DelimiterNotFound"
        case ReadFailedWithErrno(let errno): return "ReadError.ReadFailedWithErrno(\(errno))"
        }
    }
}

public func ==(lhs: ReadError, rhs: ReadError) -> Bool {
    switch (lhs, rhs) {
    case (.Eof, .Eof):             return true
    case (.Cancelled, .Cancelled): return true
    case (.Timeout, .Timeout):     return true
    case (.DelimiterNotFound, .DelimiterNotFound): return true

    case let (.ReadFailedWithErrno(e1), .ReadFailedWithErrno(e2)): return e1 == e2

    default:
        return false
    }
}

public typealias ReadResult = Result<NSData>

// Split a dispatch_data into two pieces at the given index (which must be in the range [0, size_of_data]).
private func dispatch_data_split(data: dispatch_data_t, #atIndex: UInt) -> (dispatch_data_t, dispatch_data_t) {
    let size = dispatch_data_get_size(data)
    assert(atIndex <= size, "invalid data split requested")

    let left = dispatch_data_create_subrange(data, 0, atIndex)
    let right = dispatch_data_create_subrange(data, atIndex, size - atIndex)

    return (left, right)
}

/**
*  Try to split a dispatch_data on a delimiter.
*
*  @param data      The source data.
*  @param delimiter The delimiter to search for.
*  @param offset    The starting position to begin the search (i.e., if the delimiter is known to
*                   not be present at the front of `data`).
*
*  @return If the delimiter is not found, returns (nil, data), although the data returned may not
*          be the exact same dispatch_object as the input data (but it will contain the same bytes).
*          If the delimiter is found, returns (before_delimiter, after_delimiter) - the delimiter
*          is not contained in either side.
*/
private func dispatch_data_split(data: dispatch_data_t, #delimiter: dispatch_data_t, offset: UInt = 0) -> (dispatch_data_t?, dispatch_data_t) {
    if dispatch_data_get_size(data) < offset + dispatch_data_get_size(delimiter) {
        return (nil, data)
    }

    var rawDataPointer = UnsafePointer<()>.null()
    var dataSize: UInt = 0

    // We'll use withExtendedLifetime to force keeping the returned, mapped data objects
    // around for the duration of our use of the pointers we get back (rawDataPointer and
    // rawDelimiterPointer). See the comment in the header for dispatch_data_create_map
    // use with ARC.
    return withExtendedLifetime(dispatch_data_create_map(data, &rawDataPointer, &dataSize)) {
        (contiguousData: dispatch_data_t) in

        var rawDelimiterPointer = UnsafePointer<()>.null()
        var delimiterSize: UInt = 0

        return withExtendedLifetime(dispatch_data_create_map(delimiter, &rawDelimiterPointer, &delimiterSize)) {
            var buffer = advance(UnsafePointer<UInt8>(rawDataPointer), Int(offset))

            // dumb linear search
            for i in 0 ... dataSize - (offset + delimiterSize) {
                if memcmp(buffer, rawDelimiterPointer, delimiterSize) == 0 {
                    let endFirst = offset + i
                    let beginSecond = offset + i + delimiterSize
                    return (dispatch_data_create_subrange(contiguousData, 0, endFirst),
                        dispatch_data_create_subrange(contiguousData, beginSecond, dataSize - beginSecond))
                }
                buffer = buffer.successor()
            }

            return (nil, contiguousData)
        }
    }
}

protocol ReadOperationDelegate : class {
    var bufferedData: dispatch_data_t { get set }
}

class DeferredReadOperation: DeferredIOOperation {
    // TODO: no idea why this _deferred/deferred dance is necessary, but
    // without it, accessing .deferred from DeferredReader crashes in beta4
//    let _deferred: Deferred<ReadResult> = Deferred<ReadResult>()
//    var deferred: Deferred<ReadResult> { return _deferred }
    let deferred = Deferred<ReadResult>()

    override var finished: Bool { return deferred.isFilled }

    private let maxLength: UInt
    private var data: dispatch_data_t = get_dispatch_data_empty()

    // TODO: make sure this works now
    // really want the delegate to have this type, but crashes in beta5
    private weak var delegate: ReadOperationDelegate?
//    private let delegate: ReadOperationDelegate

//    private let queueSpecificKey = UnsafeMutablePointer<()>.alloc(0)
    private let queueSpecificKey: UnsafeMutablePointer<Void> = nil

    init(delegate: ReadOperationDelegate, queue: dispatch_queue_t, source: dispatch_source_t, timerSource: dispatch_source_t, maxLength: UInt, timeout: NSTimeInterval? = nil) {
        self.delegate = delegate
        self.maxLength = maxLength
        super.init(queue: queue, source: source, timerSource: timerSource, timeout: timeout)

//        queueSpecificKey = UnsafeMutablePointer(unsafeAddressOf(self))
        queueSpecificKey = UnsafeMutablePointer.alloc(1)
        dispatch_queue_set_specific(queue, queueSpecificKey, queueSpecificKey, nil)
//        println("queue_get_specific = \(dispatch_queue_get_specific(queue, queueSpecificKey))")
    }

    deinit {
//        NSLog("DEINIT \(self)")
//        queueSpecificKey.dealloc(0)
    }

    override func cancel() {
        super.cancel()
        dispatch_async(queue) { [weak self] in
            if let s = self {
                if s.executing {
                    s.completeWithFailure(.Cancelled, withBufferedData: s.data)
                }
            }
        }
    }

    func completeWithFailure(failure: ReadError, withBufferedData: dispatch_data_t) {
        complete(.Failure(failure), withBufferedData: withBufferedData)
    }
    func completeWithSuccess(success: NSData, withBufferedData: dispatch_data_t) {
        complete(.Success(success), withBufferedData: withBufferedData)
    }
    func complete(result: ReadResult, withBufferedData: dispatch_data_t) {
        assert(dispatch_get_specific(queueSpecificKey) == queueSpecificKey, "complete called on incorrect queue")
        delegate?.bufferedData = withBufferedData

        if executing {
            suspendSources()

            executing = false
        }

        self.willChangeValueForKeyFinished()
        deferred.fill(result)
        self.didChangeValueForKeyFinished()
    }

    override func handleTimeout() {
        assert(dispatch_get_specific(queueSpecificKey) == queueSpecificKey, "complete called on incorrect queue")
        completeWithFailure(.Timeout, withBufferedData: data)
    }

    override func start() {
        dispatch_sync(queue) {
            self.realStart()
        }
    }

    private func realStart() {
        assert(dispatch_get_specific(queueSpecificKey) == queueSpecificKey, "complete called on incorrect queue")
        if self.cancelled {
            completeWithFailure(.Cancelled, withBufferedData: data)
            return
        }

        seedWithInitialData(delegate?.bufferedData ?? get_dispatch_data_empty())

        if !finished {
            executing = true
            resumeSources()
        }
    }

    func seedWithInitialData(initialData: dispatch_data_t) {
        assert(false, "must be overridden by subclasses")
    }

    func readFromSource() -> Bool {
        assert(dispatch_get_specific(queueSpecificKey) == queueSpecificKey, "complete called on incorrect queue")
        let wanted = maxLength - dispatch_data_get_size(data)
        let available = dispatch_source_get_data(source)
        let fd = Int32(dispatch_source_get_handle(source))
        let amountToRead = min(available, wanted)

        let buf = malloc(amountToRead)
        let actualRead = read(fd, buf, amountToRead)

        if actualRead > 0 {
            let newData = dispatch_data_create(buf, UInt(actualRead), nil, _dispatch_data_destructor_free)
            data = dispatch_data_create_concat(data, newData)
            return true
        } else {
            free(buf)
            if actualRead == 0 {
                completeWithFailure(.Eof, withBufferedData: data)
            } else {
                completeWithFailure(.ReadFailedWithErrno(errno), withBufferedData: data)
            }

            return false
        }
    }
}

class ReadLengthOperation: DeferredReadOperation {
    private let minLength: UInt
    private var isDataComplete: Bool { return dispatch_data_get_size(data) >= minLength }

    init(delegate: ReadOperationDelegate, queue: dispatch_queue_t, source: dispatch_source_t, timerSource: dispatch_source_t, minLength: UInt, maxLength: UInt = UInt.max, timeout: NSTimeInterval? = nil) {
        assert(maxLength >= minLength, "invalid read operation")
        self.minLength = minLength
        super.init(delegate: delegate, queue: queue, source: source, timerSource: timerSource, maxLength: maxLength, timeout: timeout)
    }

    override func seedWithInitialData(initialData: dispatch_data_t) {
        data = initialData
        if isDataComplete {
            let size = dispatch_data_get_size(data)
            let (ours, remaining) = dispatch_data_split(data, atIndex: min(size, maxLength))
            completeWithSuccess(ours as NSData, withBufferedData: remaining)
        }
    }

    override func handleEvent() {
        if readFromSource() && isDataComplete {
            // TODO: We have to make a local instance to avoid capturing self in the Result @auto_closure.
            // Remove this and confirm that we don't have a retain cycle once Result holds just T (no auto_closure).
            let localData = self.data
            completeWithSuccess(localData as NSData, withBufferedData: get_dispatch_data_empty())
        }
    }
}

class ReadDelimiterOperation: DeferredReadOperation {
    private let delimiter: dispatch_data_t
    private let delimiterSize: UInt
    private var offset: UInt = 0

    init(delegate: ReadOperationDelegate, queue: dispatch_queue_t, source: dispatch_source_t, timerSource: dispatch_source_t, delimiter: NSData, maxLength: UInt = UInt.max, timeout: NSTimeInterval? = nil) {
        self.delimiterSize = UInt(delimiter.length)
        self.delimiter = dispatch_data_create(delimiter.bytes, delimiterSize, nil, nil)
        super.init(delegate: delegate, queue: queue, source: source, timerSource: timerSource, maxLength: maxLength, timeout: timeout)
    }

    override func seedWithInitialData(initialData: dispatch_data_t) {
        var toSearch: dispatch_data_t
        var pastSearchRange: dispatch_data_t
        let size = dispatch_data_get_size(initialData)
        if size > maxLength {
            (toSearch, pastSearchRange) = dispatch_data_split(initialData, atIndex: maxLength)
        } else {
            toSearch = initialData
            pastSearchRange = get_dispatch_data_empty()
        }

        let (ours, remaining) = dispatch_data_split(toSearch, delimiter: delimiter)
//        NSLog("initial data split result: (\(ours), \(remaining))")
        if let ours = ours {
            completeWithSuccess(ours as NSData, withBufferedData: dispatch_data_create_concat(remaining, pastSearchRange))
            return
        }

        // delimiter not found - see if we've already exceeded maxLength
        if size >= maxLength {
            completeWithFailure(.DelimiterNotFound, withBufferedData: initialData)
            return
        }

        // delimiter not found but more data still to search
        data = initialData
        if size >= delimiterSize {
            // start search at this offset next time we get data
            offset = size - delimiterSize + 1
        }
    }

    override func handleEvent() {
        if !readFromSource() {
            return
        }

//        NSLog("searching for delimiter starting at \(offset)")
        let (ours, remaining) = dispatch_data_split(data, delimiter: delimiter, offset: offset)
//        NSLog("split result: (\(ours), \(remaining))")
        if let ours = ours {
            completeWithSuccess(ours as NSData, withBufferedData: remaining)
            return
        }

        // if we get here, remaining contains the same bytes as data, but remaining might be
        // contiguous even if data is discontiguous, so safe off the potentially-contiguous version
        data = remaining

        let size = dispatch_data_get_size(data)
        if size == maxLength {
            completeWithFailure(.DelimiterNotFound, withBufferedData: data)
            return
        }

        if size >= delimiterSize {
            offset = size - delimiterSize + 1
        }
    }

}