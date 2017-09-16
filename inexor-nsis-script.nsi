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

RequestExecutionLevel admin

#--------------------------------
# Interface Configuration

  SetFont /LANG=${LANG_ENGLISH} "Verdana" 10
  BrandingText " "
  SpaceTexts none

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

  # Create a page for selecting the path to an existent installation of exename.
  # ID is used to make each macro unique
  !macro CONDITIONAL_ENV_VAR_PAGE EXENAME PATHGUESS ID

    Var /GLOBAL show_env_page_${ID}
    Var skip_setting_env_${ID}
    Var path_to_${ID}

    # callback for showing the gui
    Function manual_page_${ID}
      ${If} $show_env_page_${ID} != "True"
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
  !insertmacro CONDITIONAL_ENV_VAR_PAGE "python.exe" "C:\Python27\" python
  !insertmacro CONDITIONAL_ENV_VAR_PAGE "cmake.exe" "$PROGRAMFILES64\CMake\bin" cmake
  !insertmacro MUI_PAGE_FINISH

#--------------------------------
# Get required tools for a gamer setup

  !define node_required_version "10.8.1" # "6.9.1"
  !define node_download_64 "https://nodejs.org/dist/v6.11.2/node-v6.11.2-x64.msi"

  Var has_node
  Var has_node_but_too_old
  Var tmp_value # I prefer this over registers.
  Var node_version

  Function get_nodejs
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
          MessageBox MB_OKCANCEL "Your current node.js-version is too old for Inexor: $\r$\n\
                          $node_version (required version: ${node_required_version})$\r$\n\
                          The node.js installer will be downloaded to do the upgrade.$\r$\n\
                          $\r$\n\
                          $\r$\n\
                          $\r$\n\
                          (press 'Cancel' to specify the path to an existent node.js installation lateron)" IDOK install_node IDCANCEL select_path_node
      ${Else}
          MessageBox MB_OKCANCEL "You do not seem to have node.js installed.$\r$\n\
                          The node.js installer will be downloaded to install it.\
                          $\r$\n\
                          $\r$\n\
                          $\r$\n\
                          (press 'Cancel' to specify the path to an existent node.js installation lateron)" IDOK install_node IDCANCEL select_path_node
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
          ExecWait '"msiexec" /i "$TEMP\node_latest.msi"  /passive /norestart'
          BringToFront # Come back into focus after node installer finished
          Return
      select_path_node:
        StrCpy $show_env_page_node "True"
        Return
  FunctionEnd
  
#--------------------------------
# Get required tools for a devlopment setup

# ToDo: git, visual studio
# Problem: leute sollen nicht git cli verwenden, sondern gui wählen
# Problem2: VS selbstständig runterladen ist vllt ein bisschen viel? viel: zu groß, zu viel bevormundung

# Loesung 1: gui zum wählen, mit meinung.

# Git is a solution to work on different things in the same folder (called "repository").
# You have different "branches" and "commit" your changes to files in the "branches".
# Each branch then has a history of changes of your folder.
# If you switch from branch A to branch B, your files will change in that folder to reflect the commited state of the other branch.
#
# Git gives you numerous tools by hand to partially pick the work from one branch to the other. 
# E.g. you have one useful commit in the branch A ("fix flackering lights bug"), but the rest is not ready yet, so you can cherry-pick just that one commit ("change").
# ... or a range of commits ... or you make the history of the branch look as if you made those changes on top of the latest version, not on the first-ever version.
#
# And the best thing is: you can connect that folder (aka repository) to remote ones, e.g. one is the "https://GitHub.com/inexorgame/inexor-core" repository
# where we share our work on InexorCore.
#
# Git is a whole world of awesome features. It's a lot to learn but it is worth it.

  # git: https://github.com/git-for-windows/git/releases/download/v2.14.1.windows.1/Git-2.14.1-64-bit.exe
  # https://git-scm.com/download/gui/windows

  !define python_download_64 "https://www.python.org/ftp/python/2.7.13/python-2.7.13.amd64.msi"

  !define python_manual_install_path "C:\Python27"
  Var has_python
  Var python_version

  Function get_python

   # ---------- python
    nsExec::ExectoStack 'python --version'
    pop $R0 # pop return value from stack into register $R0
    pop $R1 # pop outpout of the command: e.g. "Python 2.7.1\r\n" -> notice the useless chars
    StrCpy $1 "python_$R0" # $R0 is empty if node -v was not able to execute

    ${If} $1 == "python_"
      StrCpy $has_python "False"
    ${Else}
      # check version is high enough

      ${StrStrip} "$\r$\n" $R1 $python_version
      ${StrStrip} "Python " $python_version $python_version
      # is it python 2.x ?
      ${VersionCompare} $python_version "3.0.0" $2
      ${If} $2 == 1 # newer than 3.0
        MessageBox MB_OK "WARNING: you have python 3.x in your PATH.$\n\
                         If anything goes wrong with the build, try DOWNGRADING TO python 2.7.x!"
      ${EndIf}
    ${EndIf}

    ${If} $has_python != "False"
    #  Return
    ${EndIf}

      MessageBox MB_OKCANCEL "You do not seem to have python installed.$\r$\n\
                    The python installer will be downloaded to install it.$\r$\n\
                    $\r$\n\
                    $\r$\n\
                    $\r$\n\
                    (press 'Cancel' to specify the path to an existent python installation lateron)" IDOK install_python IDCANCEL select_path_python

      install_python:
          inetc::get /caption "python download" /BANNER "Downloading python installer from $\n${python_download_64}" ${python_download_64} "$TEMP\python_latest.msi" /end
          Pop $1 # pop return value (aka exit code) from stack, "OK" means OK
          ${If} $1 != "OK"
            MessageBox MB_OK "Sorry, there was an error downloading python$\n\
                              Aborting the installer,$\n\
                              please let us know about the circumstances of this error."
            Quit
          ${EndIf}
          # Python has no option to set the path and propagating it without a needed restart. so we manually specify the install dir and set the path with
          # our tools.
          # if they fix this, we can skip all this and just pass ADD_LOCAL=ALL to msiexec
          ExecWait '"msiexec" /i "$TEMP\python_latest.msi" TARGETDIR="${python_manual_install_path}" /norestart /passive'
          ${EnvVarUpdate} $0 "PATH" "P" "HKCU" "${python_manual_install_path}"
          ${EnvVarUpdate} $0 "PATH" "P" "HKCU" "${python_manual_install_path}\Scripts"
          BringToFront # Come back into focus after node installer finished
          Return
      select_path_python:
        StrCpy $show_env_page_python "True"
        Return
  FunctionEnd
## -----------------
# cmake
# cmake: could also be handled by conan (as build_require)
# if cmake <= 3.1 deinstall first! Installer tool has changed. Uninstall CMake 3.4 or lower first!

  !define cmake_required_version "3.10.0"
  !define cmake_download_64 "https://cmake.org/files/v3.9/cmake-3.9.1-win64-x64.msi"

  Var has_cmake
  Var has_cmake_but_too_old
  Var cmake_version

  Function get_cmake

    nsExec::ExectoStack 'cmake --version'
    pop $R0 # pop return value from stack into register $R0
    pop $R1 # pop outpout of the command: e.g. "cmake 2.7.1\r\n" -> notice the useless chars
    # namely the output is "cmake version 3.x.x\nCMake suite maintained and supported by Kitware (kitware.com/cmake).\n"
    # notice its not using \r\n but only \n as newline
    StrCpy $1 "cmake_$R0" # $R0 is empty if node -v was not able to execute

    ${If} $1 == "cmake_"
      StrCpy $has_cmake "False"
    ${Else}
      # check version is high enough

      ${StrStrip} "$\n" $R1 $cmake_version
      ${StrStrip} "cmake version " $cmake_version $cmake_version
      ${StrStrip} "CMake suite maintained and supported by Kitware (kitware.com/cmake)." $cmake_version $cmake_version

      ${VersionCompare} $cmake_version ${cmake_required_version} $2
      ${If} $2 == 2 # older than required version
        StrCpy $has_cmake "False"
        StrCpy $has_cmake_but_too_old "True"
      ${EndIf}
    ${EndIf}

    ${If} $has_cmake != "False"
      Return
    ${EndIf}

      ${If} $has_cmake_but_too_old == "True"
          MessageBox MB_OKCANCEL "Your current CMake-version is too old for Inexor: $\r$\n\
                          $cmake_version (required version: ${cmake_required_version})$\r$\n\
                          The CMake installer will be downloaded to do the upgrade.\
                          $\r$\n\
                          $\r$\n\
                          $\r$\n\
                          (press 'Cancel' to specify the path to an existent CMake installation lateron)" IDOK install_cmake IDCANCEL select_path_cmake
      ${Else}
          MessageBox MB_OKCANCEL "You do not seem to have cmake.js installed.$\r$\n\
                          The cmake.js installer will be downloaded to install it.\
                          $\r$\n\
                          $\r$\n\
                          $\r$\n\
                          (press 'Cancel' to specify the path to an existent CMake installation lateron)" IDOK install_cmake IDCANCEL select_path_cmake
      ${EndIf}

      select_path_cmake:
      install_cmake:
          inetc::get /caption "CMake download" /BANNER "Downloading CMake installer from $\n${cmake_download_64}" ${cmake_download_64} "$TEMP\cmake_latest.msi" /end
          Pop $1 # pop return value (aka exit code) from stack, "OK" means OK
          ${If} $1 != "OK"
            MessageBox MB_OK "Sorry, there was an error downloading CMake$\n\
                              Aborting the installer,$\n\
                              please let us know about the circumstances of this error."
            Quit
          ${EndIf}
          ${If} $has_cmake_but_too_old == "True"
            DetailPrint "Trying to deinstall already installed CMake"
            ExecWait 'wmic product where name="CMake" call uninstall'
          ${EndIf}
          ExecWait '"msiexec" /i "$TEMP\cmake_latest.msi" ADD_CMAKE_TO_PATH=System /passive /norestart'
          BringToFront # Come back into focus after node installer finished
          Return
      noneop:
        StrCpy $show_env_page_cmake "True"
        Return
  FunctionEnd

#--------------------------------
# Languages
 
  !insertmacro MUI_LANGUAGE "English"

#--------------------------------
# Installer Sections

#----------
# 
Section "Gaming Setup" gamingsection
  MessageBox MB_OK "Welcome to the Inexor development Setup.$\n\
                    we will guide you through the installation of all tools required to get started developing.$\n\
                    We don't know how new you are to this and will assume you have no of the default tools installed.$\n\
                    $\n\
                    So this Setup installs for you:$\n\
                    $\n\
                    - Visual Studio Community Edition$\n$\t\
                           - an Integrated Development Environment (IDE)$\n$\t\
                           - used to translate C++ source code to machine code$\n\
                    - git$\n$\t\
                            - a cooperative versioning system$\n$\t\
                            - for organizing our source base and development$\n\
                            - we let you choose an UI for it$\n\
                    - CMake$\n$\t\
                            - a metabuild system$\n$\t\
                            - used for creating our Microsoft Visual Studio projects$\n$\t\
                              from cross-platform build recipes$\n\
                    - Conan$\n$\t\
                            - a package manager$\n$\t\
                            - you do not want to re-invent technology (but to reuse it)$\n$\t\
                            - for Conan we need:$\n\
                    - Python$\n$\t\
                            - a scripting language (but used only for Conan)$\n\
                    - Node.js$\n$\t\
                            - JavaScript + JavaScript package manager$\n$\t\
                            - and just much more powerful than plain JS$\n\
                    $\n\
                    $\n\
                    You will always be able to skip the installation of a specific tool$\n\
                    (Or manually point to an existent installation)"

  MessageBox MB_OK "Finally we acquire the Inexor parts for you:$\n\
                    $\n\
                    - Get InexorFlex$\n$\t\
                            - our gamelauncher and updater$\n$\t\
                            - and actually our complete scripting system$\n$\t\
                            - written in node.js$\n$\t\
                            - it is actually a npm (node package manager) package!$\n\
                    $\n\
                    - InexorFlex installs the rest$\n$\t\
                            - the InexorCore binaries$\n$\t\
                            - essential media files...$\n\
                    $\n\
                    - InexorCore git repository gets downloaded$\n$\t\
                            - InexorCore is the C++ part of Inexor$\n$\t\
                            - so you can participate in C++ development$\n$\t\
                    $\n\
                    - InexorCore gets build$\n$\t\
                            - the first build is slow as all dependencies must$\n$\t\
                              be downloaded (and sometimes built) with Conan before$\n$\t\
                            - afterwards the Visual Studio project gets generated with CMake.$\n$\t\
                            - afterwards we build the project using Visual Studio$\n\
                    $\n\
                    $\n\
                    Lets Go!"

  ;Call get_gamesetup_tools
  ;Call get_python
SectionEnd

Section /o "Developement Setup" devsection
 # Todo: dont make normal section execute nodejs download? or hidden section
  ;Call get_devsetup_tools
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

