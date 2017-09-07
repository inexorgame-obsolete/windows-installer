# The windows installer for Inexor

Actually this is not installing any files itself.
All it does is provide a handy wrapper for other package managers or other installers.

Inexor actually gets installed with the node.js package manager (npm): `npm install -g inexor-flex` is enough to install it.
However you firstly need node.js installed and in your path (which is not always the case for normal windows users).
So we install node.js first (or upgrade it, or let the user decide to look for it manually on the PC)

For devs this setup even installs the toolchain needed to build Inexors C++ part (Inexor-core)

