//
//  Support.swift
//  ChatClient
//
//  Created by John Gallagher on 9/15/14.
//  Copyright (c) 2014 Big Nerd Ranch. All rights reserved.
//

import Foundation
import Result
import DeferredTCPSocket

func first<S: SequenceType>(sequence: S) -> S.Generator.Element? {
    var generator = sequence.generate()
    return generator.next()
}

func userFacingDescription(error: ErrorType) -> String {
    switch error {
    case let serverError as ServerError:
        return serverError.description

    case let libcError as LibCError:
        if let errnoString = String(UTF8String: strerror(libcError.errno)) {
            return "Error: \(libcError.functionName) failed with \(errnoString)"
        }

    default:
        break
    }

    return "Unknown Error"
}

extension UIAlertController {
    convenience init(error: ErrorType, handler: Void -> Void) {
        self.init(title: "Error", message: userFacingDescription(error), preferredStyle: .Alert)

        addAction(UIAlertAction(title: "OK", style: .Default, handler: { _ in handler() }))
    }
}