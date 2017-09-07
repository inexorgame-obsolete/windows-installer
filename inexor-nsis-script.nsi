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
# * modify finish page
# * create dev setup
# * shortcut
#
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
  !include "VersionCompare.nsh"
  !include "StringStrip.nsh"
  !include "EnvVarUpdate.nsh"
  !include "Detect_filepath.nsdinc"

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

#--------------------------------
# Interface Configuration

  SetFont /LANG=${LANG_ENGLISH} "Verdana" 10
  BrandingText " "

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

  !macro CONDITIONAL_ENV_VAR_PAGE EXENAME PATHGUESS ID

    Var /GLOBAL show_env_page_${ID}
    Var skip_setting_env_${ID}
    Var path_to_${ID}

  # callback for showing the gui
    Function manual_page_${ID}
      ${If} $show_env_page_${ID} == "T"
        Abort
      ${EndIf}

      Push "${PATHGUESS}"
      Push "${EXENAME}"
      Call fnc_Detect_filepath_Show
    FunctionEnd

  # Callback for setting the envvar after being about to leave the gui
    Function manual_page_leave_${ID}
      ${NSD_GetState} $hCtl_Detect_filepath_CheckBox1 $skip_setting_env_${ID}
      ${NSD_GetText} $hCtl_Detect_filepath_DirRequest1_Txt $path_to_${ID}
      ${If} $skip_setting_env_${ID} == ${BST_CHECKED}
        Return
      ${EndIf}

      ${EnvVarUpdate} $0 "PATH" "P" "HKCU" "$path_to_${ID}"
    FunctionEnd
      Page custom manual_page_${ID} manual_page_leave_${ID}
  !macroend

  !define MUI_WELCOMEPAGE_TITLE "Welcome to the ${PRODUCT_NAME} ${PRODUCT_VERSION} Setup"
  !define MUI_WELCOMEPAGE_TEXT  "Setup will guide you through the installation of ${PRODUCT_NAME} ${PRODUCT_VERSION}.$\n\
                                $\n\
                                It wraps our auto-updater but guides you through the installation of required tools as well.$\n\
                                This Setup is also an easy way to get a development setup going.$\n\
                                $\n\
                                Click Next to continue"
  !insertmacro MUI_PAGE_WELCOME
  !insertmacro MUI_PAGE_COMPONENTS
  !insertmacro MUI_PAGE_INSTFILES
  !insertmacro CONDITIONAL_ENV_VAR_PAGE "node.exe" "$PROGRAMFILES64\nodejs" node
  !insertmacro MUI_PAGE_FINISH

#--------------------------------
# Get required tools for a gamer setup

  !define node_required_version "10.8.1" # "6.9.1"
  !define node_download_64 "https://nodejs.org/dist/v6.11.2/node-v6.11.2-x64.msi"

  Var has_node
  Var has_node_but_too_old
  Var tmp_value # I prefer this over registers.
  Var node_version

  Function get_gamesetup_tools

    #------------
    # required: node.js

    nsExec::ExectoStack 'node -v'
    pop $0 # pop return value from stack into register $0
    pop $1 # pop outpout of the command: e.g. "v6.9.1\r\n" -> notice the useless chars
    StrCpy $tmp_value "node_$0" # $0 is empty if node -v was not able to execute

    ${If} $tmp_value == "node_"
      StrCpy $has_node "False" # Strcpy is misused for everything in nsis it seems.
    ${Else}
      # check version is high enough

      ${CharStrip} "v" $1 $node_version                # "v6.9.1\r\n"
      ${StrStrip} "$\r$\n" $node_version $node_version # "6.9.1\r\n"
      ${VersionCompare} $node_version ${node_required_version} $tmp_value

      ${If} $tmp_value == 2
        StrCpy $has_node "False"
        StrCpy $has_node_but_too_old "True"
      ${EndIf}
    ${EndIf}

    ${If} $has_node != "False"
      Return      
    ${EndIf}

      ${If} $has_node_but_too_old == "True"
          MessageBox MB_OKCANCEL "Your current node.js-version is too old: $\r$\n\
                          $node_version (required version: ${node_required_version})$\r$\n\
                          The node.js installer will be downloaded to do the upgrade.$\r$\n\
                          $\r$\n\
                          $\r$\n\
                          $\r$\n\
                          (press 'Cancel' to specify the path to an already installed node lateron)" IDOK install_node IDCANCEL select_path_node
      ${Else}
          MessageBox MB_OKCANCEL "You do not seem to have node.js installed.$\r$\n\
                          The node.js installer will be downloaded to do the upgrade." IDOK install_node IDCANCEL select_path_node
      ${EndIf}

      install_node:
          inetc::get /caption "node.js download" /BANNER "Downloading node.js installer from $\n${node_download_64}" ${node_download_64} "$TEMP\node_latest.msi" /end
          Pop $1 # pop return value (aka exit code) from stack, "OK" means OK
          ${If} $1 != "OK"
            MessageBox MB_OK "Sorry, there was an error downloading node.js$\n\
                              Aborting the installer,$\n\
                              please let us know about the circumstances of this error."
            Quit
          ${EndIf}
          ExecWait '"msiexec" /i "$TEMP\node_latest.msi"  /passive'
          BringToFront # Come back into focus after node installer finished
          ExecWait 'npm install npm@latest -g'
          Return
      select_path_node:
        StrCpy $show_env_page_node "True"
        Return
  FunctionEnd
  
#--------------------------------
# Get required tools for a devlopment setup

  # -----------------
  # required: python, cmake, git
  # python: https://www.python.org/ftp/python/2.7.13/python-2.7.13.amd64.msi
  # cmake: build_require?
  # if cmake <= 3.1 deinstall first! Installer tool has changed. Uninstall CMake 3.4 or lower first!
  # https://cmake.org/files/v3.9/cmake-3.9.1-win64-x64.msi
  # git: https://github.com/git-for-windows/git/releases/download/v2.14.1.windows.1/Git-2.14.1-64-bit.exe
  # GitHub Dekstop Beta: https://central.github.com/deployments/desktop/desktop/latest/win32?format=msi
/*  !define node_required_version "6.9.1"
  !define node_download_64 "https://nodejs.org/dist/v6.11.2/node-v6.11.2-x64.msi"

  Var has_node
  Var has_node_but_too_old
  Var tmp_value # I prefer this over registers.
  Var node_version
*/

  Function get_devsetup_tools
/*

    nsExec::ExectoStack 'node -v'
    pop $0 # pop return value from stack into register $0
    pop $1 # pop outpout of the command: e.g. "v6.9.1\r\n" -> notice the useless chars
    StrCpy $tmp_value "node_$0" # $0 is empty if node -v was not able to execute

    ${If} $tmp_value == "node_"
      StrCpy $has_node "False" # Strcpy is misused for everything in nsis it seems.
    ${Else}
      # check version is high enough

      ${CharStrip} "v" $1 $node_version                # "v6.9.1\r\n"
      ${StrStrip} "$\r$\n" $node_version $node_version # "6.9.1\r\n"
      ${VersionCompare} $node_version ${node_required_version} $tmp_value

      ${If} $tmp_value == 2
        StrCpy $has_node "False"
        StrCpy $has_node_but_too_old "True"
      ${EndIf}
    ${EndIf}

    ${If} $has_node != "False"
      Return      
    ${EndIf}

      ${If} $has_node_but_too_old == "True"
          MessageBox MB_OKCANCEL "Your current node.js-version is too old: $\r$\n\
                          $node_version (required version: ${node_required_version})$\r$\n\
                          The node.js installer will be downloaded to do the upgrade.$\r$\n\
                          $\r$\n\
                          $\r$\n\
                          $\r$\n\
                          (press 'Cancel' to specify the path to an already installed node lateron)" IDOK install_node IDCANCEL select_path_node
      ${Else}
          MessageBox MB_OKCANCEL "You do not seem to have node.js installed.$\r$\n\
                          The node.js installer will be downloaded to do the upgrade." IDOK install_node IDCANCEL select_path_node
      ${EndIf}

      install_node:
          inetc::get /caption "node.js download" /BANNER "Downloading node.js installer from $\n${node_download_64}" ${node_download_64} "$TEMP\node_latest.msi" /end
          Pop $1 # pop return value (aka exit code) from stack, "OK" means OK
          ${If} $1 != "OK"
            MessageBox MB_OK "Sorry, there was an error downloading node.js$\n\
                              Aborting the installer,$\n\
                              please let us know about the circumstances of this error."
            Quit
          ${EndIf}
          ExecWait '"msiexec" /i "$TEMP\node_latest.msi"  /passive'
          BringToFront # Come back into focus after node installer finished
          Return
      select_path_node:
        StrCpy $show_env_page_node "True"
        Returnf
    */
  FunctionEnd

#--------------------------------
# Languages
 
  !insertmacro MUI_LANGUAGE "English"

#--------------------------------
# Installer Sections

#----------
# 
Section "Gaming Setup" gamingsection
  Call get_gamesetup_tools
SectionEnd

Section /o "Developement Setup" devsection

SectionEnd

## The section descriptions


#--------------------------------
# Descriptions

LangString DESC_gamingsection ${LANG_ENGLISH} "The gameclient and the gameserver. The installer will install/upgrade node.js and afterwards our auto-updater.$\r$\n\
                                               The auto-updater gets the appropriate contents as you start it."
LangString DESC_devsection ${LANG_ENGLISH} "For development some more tools are needed:$\r$\n\
    Python, CMake, Conan, GIT and Visual Studio.$\r$\n\
    You will always be able to skip the installation of a specific one (although it's not recommended)."

# Assign language strings to sections
!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
  !insertmacro MUI_DESCRIPTION_TEXT ${gamingsection} $(DESC_gamingsection)
  !insertmacro MUI_DESCRIPTION_TEXT ${devsection} $(DESC_devsection)
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

