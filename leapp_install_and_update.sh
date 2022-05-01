#!/usr/bin/env bash

set -e

trap 'handleError' ERR

handleError() {
  echo ""
  echo "If you encountered an error, please consider fixing"
  echo "the script for your environment and creating a pull"
  echo "request instead of asking for support on GitHub or"
  echo "the forum. The error message above should tell you"
  echo "where and why the error happened."
}

printUsage() {
  echo "Usage: leapp_install_and_update.sh <leapp_version>"
  echo "Example: leapp_install_and_update.sh 0.12.0"
}

#-----------------------------------------------------
# Inputs
#-----------------------------------------------------
if [ -z "$1" ]; then
  printUsage
  exit 1
else
  RELEASE_VERSION=$1
fi

#-----------------------------------------------------
# Variables
#-----------------------------------------------------
INSTALLATION_DIR=~/.leapp
SILENT=false
COLOR_RED=$(tput setaf 1)
COLOR_GREEN=$(tput setaf 2)
COLOR_YELLOW=$(tput setaf 3)
COLOR_BLUE=$(tput setaf 4)
COLOR_RESET=$(tput sgr0)

print() {
    if [[ "${SILENT}" == false ]] ; then
        echo -e "$@"
    fi
}

showLogo() {
    print "${COLOR_BLUE}"
    print "  _                            "                        
    print " | |    ___  __ _ _ __  _ __   "
    print " | |   / _ \/ _\` | '_ \| '_ \  "
    print " | |__|  __/ (_| | |_) | |_) | "
    print " |_____\___|\__,_| .__/| .__/  "
    print "                 |_|   |_|     "
    print "Linux Installer and Updater"
    print "${COLOR_RESET}"
}

showHelp() {
    showLogo
    print "Available Arguments:"
    print "\t" "--help" "\t" "Show this help information"
    print "\t" "--silent" "\t" "Don't print any output"

    if [[ -n $1 ]]; then
        print "\n" "${COLOR_RED}ERROR: " "$*" "${COLOR_RESET}" "\n"
    else
        exit 0
    fi

}

#-----------------------------------------------------
# PARSE ARGUMENTS
#-----------------------------------------------------

optspec=":h-:"
while getopts "${optspec}" OPT; do
  [ "${OPT}" = " " ] && continue
  if [ "${OPT}" = "-" ]; then   # long option: reformulate OPT and OPTARG
    OPT="${OPTARG%%=*}"       # extract long option name
    OPTARG="${OPTARG#"$OPT"}"   # extract long option argument (may be empty)
    OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
  fi
  case "${OPT}" in
    h | help )     showHelp ;;
    silent )       SILENT=true ;;
    [^\?]* )       showHelp "Illegal option --${OPT}"; exit 2 ;;
    \? )           showHelp "Illegal option -${OPTARG}"; exit 2 ;;
  esac
done
shift $((OPTIND-1)) # remove parsed options and args from $@ list

#-----------------------------------------------------
# START
#-----------------------------------------------------
showLogo

#-----------------------------------------------------
print "Checking architecture..."
## uname actually gives more information than needed, but it contains all architectures (hardware and software)
ARCHITECTURE=$(uname -m -p -i || echo "NO CHECK")

if [[ $ARCHITECTURE = "NO CHECK" ]] ; then
  print "${COLOR_YELLOW}WARNING: Can't get system architecture, skipping check${COLOR_RESET}"
elif [[ $ARCHITECTURE =~ .*aarch.*|.*arm.* ]] ; then
  showHelp "Linux ARM is not supported yet"
  exit 1
elif [[ $ARCHITECTURE =~ .*i386.*|.*i686.* ]] ; then
  showHelp "32-bit systems are not supported"
  exit 1
fi

#-----------------------------------------------------
# Download Leapp
#-----------------------------------------------------

print 'Downloading Leapp...'
TEMP_DIR=$(mktemp -d)
wget --directory-prefix "${TEMP_DIR}" "https://asset.noovolari.com/latest/Leapp-${RELEASE_VERSION}.AppImage"
wget -O "${TEMP_DIR}/leapp.png" "https://github.com/Noovolari/leapp/raw/master/docs/images/icon.png"

#-----------------------------------------------------
print 'Installing Leapp...'
# Delete previous version
rm -f ${INSTALLATION_DIR}/*.AppImage ~/.local/share/applications/leapp.desktop

# Creates the folder where the binary will be stored
mkdir -p ${INSTALLATION_DIR}

# Download the latest version
mv "${TEMP_DIR}/Leapp-${RELEASE_VERSION}.AppImage" "${INSTALLATION_DIR}/Leapp-${RELEASE_VERSION}.AppImage"

# Gives execution privileges
chmod +x "${INSTALLATION_DIR}/Leapp-${RELEASE_VERSION}.AppImage"

print "${COLOR_GREEN}OK${COLOR_RESET}"

#-----------------------------------------------------
print 'Installing icon...'
mv "${TEMP_DIR}/leapp.png" "${INSTALLATION_DIR}/leapp.png"
print "${COLOR_GREEN}OK${COLOR_RESET}"

# Detect desktop environment
if [ "$XDG_CURRENT_DESKTOP" = "" ]
then
  DESKTOP=$(echo "${XDG_DATA_DIRS}" | sed 's/.*\(xfce\|kde\|gnome\).*/\1/')
else
  DESKTOP=$XDG_CURRENT_DESKTOP
fi
DESKTOP=${DESKTOP,,}  # convert to lower case

echo 'Create Desktop icon...'

# Detect distribution environment, and apply --no-sandbox fix
SANDBOXPARAM=""
# lsb_release isn't available on some platforms (e.g. opensuse)
# The equivalent of lsb_release in OpenSuse is the file /usr/lib/os-release
if command -v lsb_release &> /dev/null; then
  DISTVER=$(lsb_release -is) && DISTVER=$DISTVER$(lsb_release -rs)
  DISTCODENAME=$(lsb_release -cs)
  DISTMAJOR=$(lsb_release -rs|cut -d. -f1)
  #-----------------------------------------------------
  # Check for "The SUID sandbox helper binary was found, but is not configured correctly" problem.
  # It is present in Debian 1X. A (temporary) patch will be applied at .desktop file
  # Linux Mint 4 Debbie is based on Debian 10 and requires the same param handling.
  if [[ $DISTVER =~ Debian1. ]] || [ "$DISTVER" = "Linuxmint4" ] && [ "$DISTCODENAME" = "debbie" ] || [ "$DISTVER" = "CentOS" ] && [[ "$DISTMAJOR" =~ 6|7 ]]
  then
    SANDBOXPARAM="--no-sandbox"
  fi
fi

# Initially only desktop environments that were confirmed to use desktop files stored in
# `.local/share/desktop` had a desktop file created.
# However some environments don't return a desktop BUT still support these desktop files
# the command check was added to support all Desktops that have support for the
# freedesktop standard 
# The old checks are left in place for historical reasons, but
# NO MORE DESKTOP ENVIRONMENTS SHOULD BE ADDED
# If a new environment needs to be supported, then the command check section should be re-thought
if [[ $DESKTOP =~ .*gnome.*|.*kde.*|.*xfce.*|.*mate.*|.*lxqt.*|.*unity.*|.*x-cinnamon.*|.*deepin.*|.*pantheon.*|.*lxde.*|.*i3.*|.*sway.* ]] || [[ $(command -v update-desktop-database) ]]
then
    # Only delete the desktop file if it will be replaced
    rm -f ~/.local/share/applications/appimagekit-leapp.desktop

    # On some systems this directory doesn't exist by default
    mkdir -p ~/.local/share/applications
    
    # Tabs specifically, and not spaces, are needed for indentation with Bash heredocs
    cat >> ~/.local/share/applications/appimagekit-leapp.desktop <<-EOF
	[Desktop Entry]
	Encoding=UTF-8
	Name=Leapp
  Description=Noovolari Leapp
	Comment=DevTool to access your cloud 
	Exec=${INSTALLATION_DIR}/Leapp-${RELEASE_VERSION}.AppImage ${SANDBOXPARAM} %u
	Icon=${INSTALLATION_DIR}/leapp.png
	StartupWMClass=Leapp
	Type=Application
	Categories=Development;
	MimeType=x-scheme-handler/leapp;
	X-GNOME-SingleWindow=true // should be removed eventually as it was upstream to be an XDG specification
	SingleMainWindow=true
	EOF
    
    # Update application icons
    [[ $(command -v update-desktop-database) ]] && update-desktop-database ~/.local/share/applications && update-desktop-database ~/.local/share/icons
    print "${COLOR_GREEN}OK${COLOR_RESET}"
else
    print "${COLOR_RED}NOT DONE, unknown desktop '${DESKTOP}'${COLOR_RESET}"
fi

#-----------------------------------------------------
# FINISH INSTALLATION
#-----------------------------------------------------

# Informs the user that it has been installed
print "${COLOR_GREEN}Leapp version${COLOR_RESET} ${RELEASE_VERSION} ${COLOR_GREEN}installed.${COLOR_RESET}"

#-----------------------------------------------------
print "Cleaning up..."
rm -rf "$TEMP_DIR"
print "${COLOR_GREEN}OK${COLOR_RESET}"
