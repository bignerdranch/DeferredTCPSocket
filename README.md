# DeferredTCPSocket

DeferredTCPSocket is a Swift framework for asynchronous TCP networking.

## <a name="overview"></a>Overview

DeferredTCPSocket uses [Deferred](https://github.com/bignerdranch/Deferred) to
present a type-safe, powerful interface for TCP networking. It is built on top
of the GCD I/O channels API (`dispatch_io_create` and friends).
DeferredTCPSocket also makes extensive use of
[Result](https://github.com/bignerdranch/Result) for reporting errors.

This framework should be considered alpha quality! It is likely to change,
potentially in breaking ways, in the future.

## Usage - Server

To start a TCP server, you need to supply a port to listen on (use 0 for a random
one, just like for C's `bind`) and a connection handler, which is a tuple of
a GCD queue and a function to run for each client that connects.

```swift
func handleConnection(socket: TCPCommSocket) {
		// This will be called on the queue we provide below whenever a client connects.
}

let connHandler = (dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)!,
                   handleConnection)
let acceptResult = TCPAcceptSocket.accept(onPort: 12345, withConnectionHandler: connHandler)

switch acceptResult {
case let .Success(acceptSocket):
		// Note the use of () to call the acceptSocket. This is to work around a bug
		// in the Swift compiler, and hopefully will eventually be unnecessary.
		runYourProgram(acceptSocket())

case let .Failure(error):
		println("Could not start listening: \(error)")
}
```

To interact with the client connection, you receive a `TCPCommSocket`. See the
[Client](#client) section below for usage of `TCPCommSocket`.

For more involved examples, see the Examples directory. EchoServer is a basic implementation
of a server that echos back anything clients send, and ChatServer is a simple IRC-like
server (ChatClient is an iOS client for the server).

## <a name="client"></a>Usage - Client

To connect to a TCP server, you need to supply a hostname and a port or service
name.  Both of these will be passed to the C function
[getaddrinfo](http://www.beej.us/guide/bgnet/output/html/multipage/getaddrinfoman.html).
Connecting is a blocking operation, so attempting to connect returns a
`Deferred<Result<TCPCommSocket>>` (see the [overview](#overview) for links to
`Deferred` and `Result`).

If the connection is successful, `TCPCommSocket` has a number of methods for
reading and writing data:

```swift
// All read methods return a Deferred<Result<NSData>>

// Read the first available data.
readData()

// Read the first available data, failing if no data is available before a timeout.
readDataWithTimeout(timeout: NSTimeInterval)

// Read `length` bytes of data, optionally with a timeout.
readDataToLength(length: UInt, withTimeout timeout: NSTimeInterval? = nil)

// Read data until a delimiter (such as a newline) is encountered. The delimiter is
// not included in the returned data. `maxLength` allows you to specify a limit to
// how much data will be buffered up waiting for the delimiter.
readDataToDelimiter(delimiter: NSData,
                    maxLength: UInt = default,
                    withTimeout timeout: NSTimeInterval? = nil)

// All write methods return a Deferred<Result<()>>, that is, a Result that may be
// .Success (with no meaningful associated value) or a .Failure with an error.

// Write all of `data`, optionally with a timeout.
writeData(data: NSData, withTimeout timeout: NSTimeInterval? = nil)

// Convenience method to write a string in a given encoding, optionally with a timeout.
writeString(string: String,
            withEncoding encoding: NSStringEncoding = NSUTF8StringEncoding,
            timeout: NSTimeInterval? = nil)
```

If you run the EchoServer from the Examples directory, the following code will act as a
client, send a single string, read the response, and disconnect:

```swift
let connection = TCPCommSocket.connectToHost("localhost", serviceOrPort: "44444")
connection.upon { (result) -> () in
		// in real code, don't do this! handle the error case.
    let socket = result.successValue!

		// again in real code, don't ignore the result of writing - handle the error case.
    socket.writeString("Hello!\n", withEncoding: NSUTF8StringEncoding).upon { _ in

        socket.readDataWithTimeout(1.0).upon { readResult in
            println("read result: \(readResult)")
            socket.close()
        }
    }
}
```

A final note on memory management. The underlying socket will be closed will be
closed when the `TCPCommSocket` is deallocated. If your read or write
operations are being cancelled prematurely, make sure you are retaining the
`TCPCommSocket`.

## Integration

Add this repository as a submodule, or use [Carthage](https://github.com/Carthage/Carthage/).

Note that this repository includes two other repos as submodules.

## Author

John Gallagher, jgallagher@bignerdranch.com

## License

Deferred is available under the MIT license. See the LICENSE file for more info.
