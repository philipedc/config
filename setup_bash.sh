#!/bin/bash -e

# Colors
RC='\033[0m'    
RED='\033[31m'
YELLOW='\033[33m'
GREEN='\033[32m'

# Optional packages
ZOXIDE="zoxide"
TMUX="tmux"
TRASH_CLI="trash-cli"

# If you execute with sudo, check which user
if [ "$SUDO_USER" ]; then
    TARGET_HOME="/TARGET_HOME/${SUDO_USER}"
else
    TARGET_HOME="$TARGET_HOME"
fi

# Function Definitions

ask_install() {
    local PACKAGE="$1"
    local QUESTION="Do you want to install $PACKAGE?"

    while true; do
        echo -e "${YELLOW}$QUESTION (y/n)${RC}"  # Use -e to enable interpretation of backslash escapes
        read response
        case $response in
            [yY]* ) break;;
            [nN]* ) eval "${PACKAGE}=''" ; break;;
            * ) echo -e "${RED}Invalid response. Please, type y or n.${RC}";;
        esac
    done
}

command_exists() {
    command -v "$1" > /dev/null
}

check_env() {
    echo -e "${YELLOW}Checking environment...${RC}"
    local POSSIBLE_PACKAGE_MANAGERS="apt apt-get dnf pacman yum zypper apk nix-env"

    for pm in $POSSIBLE_PACKAGE_MANAGERS; do
        if command_exists "$pm"; then
            PACKAGE_MANAGER="$pm"
            break
        fi
    done
    if [ -z "$PACKAGE_MANAGER" ]; then
        echo -e "${RED}No package manager found. Exiting.${RC}"
        exit 1
    fi

    if command_exists "sudo"; then
        SUDO_CMD="sudo"
    elif command_exists "doas" && [ -f "/etc/doas.conf" ]; then
        SUDO_CMD="doas"
    else
        SUDO_CMD="su -c"
    fi

    echo -e "${GREEN}Using package manager: $PACKAGE_MANAGER${RC}"

    # Check if the current directory is writable
    SCRIPT_PATH=$(dirname "$(realpath "$0")")
    if [ ! -w "$SCRIPT_PATH" ]; then
        echo -e "${RED}Current directory is not writable. Exiting.${RC}"
        exit 1
    fi

    POSSIBLE_SUPERGROUPS="wheel sudo root adm"
    for sg in $POSSIBLE_SUPERGROUPS; do
        if groups | grep -q "$sg"; then
            SUGROUP="$sg"
            break
        fi
    done
    if [ -z "$SUGROUP" ]; then
        echo -e "${RED}No supergroup found. Exiting.${RC}"
        exit 1
    fi

    if ! groups | grep -q "$SUGROUP"; then
        echo -e "${RED}Current user is not in the $SUGROUP group. Exiting.${RC}"
        exit 1
    fi
}

install_packages() {
    echo -e "${YELLOW}Installing packages...${RC}"
    local DEPENDENCIES="bash bash-completion ripgrep $TRASH_CLI $TMUX $ZOXIDE"

    if [ "$PACKAGE_MANAGER" = "apt" ]; then
        $SUDO_CMD $PACKAGE_MANAGER install -y $DEPENDENCIES
    fi
}

configure_package() {

	local PACKAGE_NAME="$1"
	local SYSTEM_CONFIGURATION_PATH="$2"
	local SCRIPT_CONFIGURATION_PATH="${BUILD_DIR}/$(basename ${SYSTEM_CONFIGURATION_PATH})"

	# if package was not chosen, return
	if [ -z "$PACKAGE_NAME" ]; then
		return
	fi

	echo -e "${YELLOW}Configuring package ${PACKAGE_NAME}...${RC}"

	if [ -f "$SYSTEM_CONFIGURATION_PATH" ]; then
		echo -e "${YELLOW}Configuration file already exists.${RC}"
		if command_exists "trash"; then
            echo -e "${YELLOW}Moving old configuration file to trash.${RC}"
            trash "$SYSTEM_CONFIGURATION_PATH"
        else
            echo -e "${YELLOW}Removing old configuration file.${RC}"
            rm "$SYSTEM_CONFIGURATION_PATH"
        fi
	fi
	echo -e "${GREEN}Creating configuration file: ${SYSTEM_CONFIGURATION_PATH}${RC}"
	mv "${SCRIPT_CONFIGURATION_PATH}" "$SYSTEM_CONFIGURATION_PATH"
}

# Main script

# Create a temporary build directory
BUILD_DIR=$(mktemp -d)

# Check if string BUILD_DIR is empty
if [ -z "$BUILD_DIR" ]; then
    echo -e "${RED}Failed to run 'mktemp -d'. Exiting.${RC}"
    exit 1
fi


echo -e "${YELLOW}Cloning repository into: ${BUILD_DIR}${RC}"
git clone --depth=1 https://github.com/philipedc/config $BUILD_DIR --quiet
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Successfully cloned repository${RC}"
else
    echo -e "${RED}Failed to clone repository${RC}"
    exit 1
fi

# UserID 0 is root
if [ "$EUID" -eq 0 ]; then
    check_env

    ask_install "ZOXIDE"
    ask_install "TMUX"
    ask_install "TRASH_CLI"
    
    install_packages
else
    echo -e "${YELLOW} Running without root privileges, skipping package installation.${RC}"
fi

if command_exists "tmux"; then
    configure_package "$TMUX" "${TARGET_HOME}/.tmux.conf"
fi
configure_package "bash" "${TARGET_HOME}/.bashrc"