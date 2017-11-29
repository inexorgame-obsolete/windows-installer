# NSIS installer script
#
# NSIS handling in "short":
#
# The language has include and even plugins (which you still need to manually install by downloading a bunch of .dll's. We use the inetc plugin).
# BUT its very very low level.
# You have normal variables, which you create with "Var pingpongvar" and access with $pingpongvar, and you have macros which you define with !define dingvar
# and access with ${dingvar}.
# HOWEVER all of these are global. There are no scopes for these so-called "user defined" variables.
# As you might guess here there are also not "user defined" variables, but hardcoded ones (you may call them registers).
# Namely $0 $1 $2 $3 $4 ... $9 $R1 .. $R9
# The advantage is simply that you do not have a bunch of "Var tempvalueA\n Var tempvalueB\n Var tempvalueC ..." at the top of your script each time.
# Furthermore those registers are local inside functions as well.
# Oh yeah: You have functions and functions won't return values from there, but push it on a stack.
# Afterwards you Pop the topmost from the stack to get the value back.
# E.g. the function getpi does `Push 3.14` and after you `Call getpi` to execute the function you `Pop $my_pi_var` to get the topmost value from the stack
# into your $my_pi_var variable.
# Yes. Its low-level.
# You don't even have if-else (or any control statements besides goto), but they are rebuilt with macros ${If} valA operator valB ... ยง{Else} ... ${EndIf}
# (in LogicLib.nsh header file)
# Goto on the other side is used extensively. Labels are local to functions (a label is the target of a goto, e.g. `kill_a_kitty: Call "ask_your_ex_for_a_coffee"`).
# Often they are used as callbacks from dialogs and such (you specify the label for success and
# the label for cancel when you open a `MessageBox MB_YESNO "Are you sure?" IDYES kill_a_kitty IDNO go_on_without`)
# Oddest issue last: you do not set variables. There is no $my_variable = true or $my_variable = 20, you copy into it with Strcpy $is_installed true
# (alternatively you "Push 20" onto the stack and thereafter "Pop $my_variable" it from the stack into your var
#
# 
# Besides using an old-fashioned language this script does:
# * provide a gamer- and a developer setup
# * check whether required software is installed (including a version check)
#     * If software is not installed:
#     * check for user feedback (yes no "download and install xy?")
#     * download the installer for xy and execute it.
#     * add it to path if you didn't download it, but chose to look for it on the hard drive
# * executes npm install -g inexor-flex --upgrade to get our launcher/scripting env inexor-flex (which can download the remaining Inexor files).
# * "git clone inexor-core" if development installation was chosen
# * adds a shortcut to the start menu
#
# TODO:
# * git page
# * make the checks before the installation.
# *   -> each check gets followed by the new page.
#        otherwise the download will be executed
#        the pages are numbered
# * modify finish page
# * create dev setup

# later to maybe do:
# * tells the firewall Inexor.exe is harmeless (maybe flex would need to do this?)
# * test with proxy settings


#--------------------------------
#Includes

  !include "MUI2.nsh"
  !include "WinVer.nsh"
  !include "x64.nsh"
  !include "nsDialogs.nsh"
  !include "LogicLib.nsh"

#--------------------------------
#General

!define PRODUCT_NAME "Inexor"
!define PRODUCT_VERSION "alpha"
!define PRODUCT_PUBLISHER "Inexor Team"
!define PRODUCT_WEB_SITE "https://inexor.org"
!define HELPURL "https://github.com/inexorgame/inexor-core/issues"

Name "${PRODUCT_NAME} ${PRODUCT_VERSION}"
OutFile "${PRODUCT_NAME}_Setup.exe"

RequestExecutionLevel user

SetCompressor /SOLID lzma
#--------------------------------
# Interface Configuration

  SetFont /LANG=${LANG_ENGLISH} "Verdana" 10
  BrandingText " "
 # SpaceTexts none

  !define MUI_HEADERIMAGE
  !define MUI_HEADERIMAGE_BITMAP "InexorInstaller_150x57.bmp" # optional
  #!define MUI_HEADERIMAGE_BITMAP_STRETCH NoStretchNoCrop
  #!define MUI_ABORTWARNING

  !define MUI_ICON "Inexor_Icon_48px.ico"
  !define MUI_PAGE_HEADER_TEXT "Inexor installation helper"

  !define MUI_WELCOMEFINISHPAGE_BITMAP "InexorInstaller_164x314.bmp"
  !define MUI_LICENSEPAGE

#--------------------------------
# Pages
  !define MUI_FINISHPAGE_NOAUTOCLOSE
  !define MUI_INSTFILESPAGE_NOAUTOCLOSE

  !define MUI_WELCOMEPAGE_TITLE "Welcome to the ${PRODUCT_NAME} ${PRODUCT_VERSION} Setup"
  !define MUI_WELCOMEPAGE_TEXT  "Setup will guide you through the installation of ${PRODUCT_NAME} ${PRODUCT_VERSION}.$\n\
                                $\n\
                                It wraps our auto-updater but guides you through the installation of required tools as well.$\n\
                                $\n\
                                Click Next to continue"
                              #  This Setup is also an easy way to get a development setup going.$\n\

  !insertmacro MUI_PAGE_WELCOME
 # !insertmacro MUI_PAGE_COMPONENTS

#  !define MUI_PAGE_HEADER_TEXT "Choose Inexor install location"
 # !define MUI_PAGE_HEADER_SUBTEXT "Adapt the folder the downloader and scripting system get installed into"
  !define MUI_DIRECTORYPAGE_TEXT_TOP "$\n$\nATTENTION: Folder should not require higher permission to be written into. $\n\
                                     The My Games folder is our default recommendation."
  !define MUI_DIRECTORYPAGE_TEXT_DESTINATION "Inexor folder:"
  InstallDir "$DOCUMENTS\My Games\Inexor\"
  !insertmacro MUI_PAGE_DIRECTORY

  !insertmacro MUI_PAGE_INSTFILES
  !define MUI_FINISHPAGE_TEXT "The Inexor setup completed to install InexorFlex.$\n\
                               Start InexoFlex to complete the rest of the installation (downloading media files, downloading InexorCore releases..)"
  !define FLEX_EXE_CMD "$INSTDIR\flex\start_inexor_flex.bat"
  !define MUI_FINISHPAGE_RUN "${FLEX_EXE_CMD}"
  !define MUI_FINISHPAGE_RUN_TEXT "Start InexorFlex to do the remaining installation."
  !insertmacro MUI_PAGE_FINISH

#--------------------------------
# Get required tools for a gamer setup


  # Install InexorFlex via npm and add the bin folder to the PATH.
  Function create_shortcuts
    ## First we need to install the icon

    # define the output path for this file
    SetOutPath "$INSTDIR\flex"
    # define what to install and place it in the output path
    File Inexor_Icon_256px.ico

    CreateShortCut "$DESKTOP\Inexor.lnk" "${FLEX_EXE_CMD}" "" "$INSTDIR\flex\Inexor_Icon_256px.ico" 0
  FunctionEnd

#--------------------------------
# Languages
 
  !insertmacro MUI_LANGUAGE "English"

#--------------------------------
# Installer Sections

#----------
# 
Section "Gaming Setup" gamingsection
  # If player setup:
  # install node silently (remove folder if there)
  # install inexor-flex, add it to the PATH
  # Install inexor.bat, create shortcut on inexor.bat
  # let inexor-flex do the rest on first start: download core, download media-essential/media-additional.
  SetOutPath "$INSTDIR\flex"
  # File /r "flex\*"
  File start_inexor_flex.bat
  # Unpack nodejs
  SetOutPath "$TEMP\inexorinst"
  File /r "7z\*"
  File node.zip
  File flex.7z
  nsExec::ExectoLog '"$TEMP\inexorinst\x64\7za" x -y "$TEMP\inexorinst\flex.7z" "-o$INSTDIR/flex/"'
  nsExec::ExectoLog '"$TEMP\inexorinst\x64\7za" x -y "$TEMP\inexorinst\node.zip" "-o$INSTDIR/flex/"'
  Call create_shortcuts
SectionEnd

## The section descriptions


#--------------------------------
# Descriptions

LangString DESC_gamingsection ${LANG_ENGLISH} "The gameclient and the gameserver. The installer will install/upgrade node.js and afterwards our auto-updater.$\r$\n\
                                               The auto-updater gets the appropriate contents as you start it."

# Assign language strings to sections
!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
  !insertmacro MUI_DESCRIPTION_TEXT ${gamingsection} $(DESC_gamingsection)
!insertmacro MUI_FUNCTION_DESCRIPTION_END


#--------------------------------
# Check windows version on initialisation
#
# and make gamingsection read only

  Function .onInit
    ${IfNot} ${AtLeastWin7}
      MessageBox MB_OK "Windows 7 or newer required"
      Quit
    ${EndIf}
    ${IfNot} ${RunningX64}
      MessageBox MB_OK "Sorry, currently no prebuilt windows binaries available for 32 bit.$\n Tell the Inexor Crew to let them kick off a build."
      Quit
    ${EndIf}

    # set section 'gamingsection' as selected and read-only
    IntOp $0 ${SF_SELECTED} | ${SF_RO}
    SectionSetFlags ${gamingsection} $0

  FunctionEnd
