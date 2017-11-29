@echo off

:: Folder must be high level to avoid hitting windows' short path length limit..
SET "INSTALLER_FOLDER=C:\inst"
SET "FULL_NODE_VERSION=v%nodejs_version%"
SET "ARCH=%nodejs_arch%"

:: Create the flex folder.
cd %INSTALLER_FOLDER%
mkdir flex

cd flex
call npm install @inexorgame/inexor-flex
7z a flex.7z node_modules\
move /y "flex.7z" "%INSTALLER_FOLDER%\"

cd %INSTALLER_FOLDER%
:: Git clone the interfaces
:: Git clone the media repos
:: Git clone the release
:: OR: use inexor-flex to do all this in one step.

:: Download node.js zip. we unpack it with the installer
curl -fsSL -o node.zip https://nodejs.org/download/release/%FULL_NODE_VERSION%/node-%FULL_NODE_VERSION%-win-%ARCH%.zip

makensis.exe inexor-nsis-script.nsi
