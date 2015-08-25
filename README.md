# networking
A basic networking module for the [Monkey programming language](https://github.com/blitz-research/monkey).

This module acts as a successor to the ['regalnet'](https://bitbucket.org/ImmutableOctet/regalnet) module, development of which has been discontinued. This module is my attempt at fixing some of the mistakes made with RegalNET. This module is not API (Or binary) compatible with RegalNET.

Functionality provided in this repository is experimental, and not yet meant for common use-cases. For this reason, this has yet to be added to the [main "modules" repository](https://github.com/Regal-Internet-Brothers/modules). Use this module at your own risk. Long-term API compatibility can only be partially assumed.

Currently, both UDP and TCP are supported, and *advanced* features like packet routing are not currently available. UDP-reliability is currently experimental. This module uses the ['brl.socket'](https://github.com/blitz-research/monkey/blob/develop/modules/brl/socket.monkey) module as a backend. Portability currently depends on this module.

TODO:
* Implement packet sorting / short-term storage.
* Implement packet routing for client-to-client communications.
