# mruby Sandbox

A mruby sandbox whose job is to run untrusted ruby code in a safe environment.
It can be controlled through STDIN and STDOUT. Untrusted code is loaded into an
environment having no access to the outside world.

The sandbox is meant to run as a subprocess of a managing parent process. To
be able to communicate with its parent the sandbox also loads a restricted
implementation of the IO library that only allows reading and writing to io
endpoints the parent passed down to the sandbox. The IO library does not
implement any operations creating new endpoints, accessing files on the system
or the like.

The communication between the sandbox and its parent uses an rpc mechanism.
Both sides can export objects which methods can be called from the other side
of the sandbox.

