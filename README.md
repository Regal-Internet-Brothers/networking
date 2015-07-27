# networking
A basic networking module for the [Monkey programming language](https://github.com/blitz-research/monkey).

This module acts as a successor to the ['regalnet'](https://bitbucket.org/ImmutableOctet/regalnet) module, development of which has been discontinued. This module is my attempt at fixing some of the mistakes made with RegalNET. This module is not API (Or binary) compatible with RegalNET.

Currently, only UDP is supported, and *advanced* features like packet sorting and reliability are not currently available. This module uses the ['brl.socket'](https://github.com/blitz-research/monkey/blob/develop/modules/brl/socket.monkey) module as a backend. Portability currently depends on this module.

TODO:
* Implement reliable packets.
* Implement packet sorting / short-term storage.
* Adjust the packet format to better suit TCP.
* Implement *advanced* binding and sending features for clients.
