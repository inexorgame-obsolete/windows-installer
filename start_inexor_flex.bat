@echo off

SET "PATH=%~dp0node-v8.3.0-win-x64;%PATH%"

::SET "INEXOR_CONFIG_PATH=%~dp0..\config"
SET "INEXOR_MEDIA_PATH=%~dp0..\media"
SET "INEXOR_RELEASES_PATH=%~dp0.."
SET "INEXOR_INTERFACES_PATH=%~dp0..\interfaces"

CD %~dp0node_modules\@inexorgame\inexor-flex
START npm start
