# networking
A data-oriented networking framework for the [Monkey programming language](https://github.com/blitz-research/monkey).

**Documentation for this project [can be found here](http://regal-internet-brothers.github.io/networking).** *(Reasonably finished)*

This was built as an easy to use API that allows you to serialize and deserialize data using the internet transport layer (TCP & UDP). This framework handles the lower level side of networking; client management, packet semantics, etc. This allows you to focus on the I/O aspects of your game's networking, rather than the protocol behavior. Everything's done using standard 'Stream' objects, meaning any standard input or output routine could be used on a packet-stream.

**For an excellent example of how this module is used, and how you can abstract I/O from networking, view the ["cursor demo"](/Examples/Cursor_Example.monkey).** That demo follows several good practices for game networking. For basic message I/O, [this demo](/Examples/Basic_Send_Example.monkey) should help. And for "mega packet" (File) I/O, [this](/Examples/Network_File_Test.monkey) is a solid reference.

## Features:
* **Protocol agnostic (TCP or UDP)**; as long as both ends use the same protocol, there should be no code changes. (Please use reliable messages where necessary, even when using TCP)

* **Reliable messaging**; send your packets, and decide if you should care if they need to be received. When using TCP, all messages are guaranteed to make it reliably, and in order, without any added overhead from your software. For UDP, packets are not guaranteed to be in order, but if tagged as such, they will be reliable. Packet ordering is protocol dependent, but this can be controlled regardless of the protocol, by using "mega packets".

* **Stanard 'Stream' utilization**; build the bulk of your application ignoring where the data comes from. Focus on I/O where it matters, and networking when you need to care about what goes over the line. Write and use your packets like normal 'Streams', without having to deal with byte-order or lower level packet-format details. Just name your messages and send.

* **"Mega packets"**; an optimal way of chaining together 'Packet' objects for long messages, without the need for multi-page long buffers. Send data in bulk to a client, or a remote host. Send large files (Configurable), no matter the protocol, and get everything back in proper order. (Multi-part/extended packets)

* **Configurable standard packet sizes**. **NOTE**: Do not use a packet size higher than the protocol allows. Use "mega packets" when making long messages regardless of the protocol. If the message is smaller than a normal 'Packet' object, only one will be allocated.

* **Client identification, connection, disconnection, and timeouts**. Handle individual clients, get notified when they're connecting, accepted, or terminated. Send to all clients, or individual clients.

* **Decide who connects, and when**; filter allowed addresses, only allow a single client, or limit the number of connections yourself.

* **Extend the framework**; most routines are *protected*, meaning any extending class can use them. Write packets yourself, handle internal messages, and add features. Everything is open source, and open to extension.

## API Disclaimer:
This module acts as a successor to the ['regalnet'](https://bitbucket.org/ImmutableOctet/regalnet) module, development of which has been discontinued. This module aims to replace that module, though it is not API, or binary compatible with it.

Functionality provided in this repository was *(Until recently)* very experimental. Though this is now an officially supported module, it is still in relatively early development, and may still see some API changes. That being said, this should be stable enough for most use-cases. Use this module at your own risk. Long-term API compatibility may be assumed, but some implementation details may change. Feel free to stick with older versions if newer commits are unstable. I'm still unsure if I'm going to need multiple branches or not. In the event I do, it will likely be named "experimental", and cover new features.

### Notes:
*UDP-reliability has been considered working for a long time, though advanced stability testing has yet to be done.*

This module uses the ['brl.socket'](https://github.com/blitz-research/monkey/blob/develop/modules/brl/socket.monkey) module as a backend. Portability currently depends on this module.

### TODO:
* Optimize UDP reliable-packet output. (Asynchronous bottleneck)
* Implement packet routing for client-to-client communications. (Potential security problems)
