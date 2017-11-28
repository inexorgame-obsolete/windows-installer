# The windows installer for Inexor

Inexor actually gets installed with the node.js package manager (npm): `npm install -g inexor-flex` is enough to install it.
However you firstly need node.js installed and in your path (which is not always the case for normal windows users).
Furthermore currently node.js needs to be installed in a specific version (see https://github.com/nodegit/nodegit/blob/master/appveyor.yml#L30)

So we ship node.js and inexor-flex.


We plan to provide an advanced setup which installs a dev environment as well.


### Notes:

To upgrade the shipped node.js you need to:

1. Change the nodejs version in appveyor.yml
2. **Change the nodejs version in start_inexor_flex.bat**
