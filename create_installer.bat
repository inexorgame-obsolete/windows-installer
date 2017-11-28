@echo off

:: Folder must be high level to avoid hitting windows' short path length limit..
SET "INSTALLER_FOLDER=C:\inst"
SET "FULL_NODE_VERSION=v%nodejs_version%"
SET "ARCH=x64"

:: Create the flex folder.
cd %INSTALLER_FOLDER%
mkdir flex

cd flex
npm install @inexorgame/inexor-flex

cd %INSTALLER_FOLDER%
:: Git clone the interfaces
:: Git clone the media repos
:: Git clone the release
:: OR: use inexor-flex to do all this in one step.

:: Download and unpack nodejs to flex
curl -fsSL -o node.zip https://nodejs.org/download/release/%FULL_NODE_VERSION%/node-%FULL_NODE_VERSION%-win-%ARCH%.zip
7z e -y node.zip -o%INSTALLER_FOLDER%/flex


makensis.exe inexor-nsis-script.nsi
