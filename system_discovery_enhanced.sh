#!/bin/bash

# =====================================================
# System Discovery Automation Script with Automatic Tool Installation
# and Amazon Linux Support
# =====================================================
# This script performs various system discovery tasks
# based on MITRE ATT&CK techniques.
# It is designed to run on Linux (including Amazon Linux),
# macOS, and Windows (via Git Bash, Cygwin, or WSL).
# Some steps may require administrative privileges.
# =====================================================

# Function to detect the operating system and distribution
detect_os() {
    echo -e "\n\033[1;34mDetecting Operating System...\033[0m\n"
    OS_TYPE="$(uname -s)"
    case "${OS_TYPE}" in
        Linux*)
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                case "${ID}" in
                    amzn)
                        OS=AmazonLinux
                        DISTRO=AmazonLinux
                        ;;
                    ubuntu)
                        OS=Linux
                        DISTRO=Ubuntu
                        ;;
                    fedora)
                        OS=Linux
                        DISTRO=Fedora
                        ;;
                    centos)
                        OS=Linux
                        DISTRO=CentOS
                        ;;
                    debian)
                        OS=Linux
                        DISTRO=Debian
                        ;;
                    *)
                        OS=Linux
                        DISTRO=Unknown
                        ;;
                esac
            else
                OS=Linux
                DISTRO=Unknown
            fi
            ;;
        Darwin*)
            OS=Mac
            DISTRO=Unknown
            ;;
        CYGWIN*|MINGW*|MSYS*)
            OS=Windows
            DISTRO=Unknown
            ;;
        *)
            OS=Unknown
            DISTRO=Unknown
            ;;
    esac
    echo -e "\033[1;34mDetected OS: $OS\033[0m"
    if [ "$DISTRO" != "Unknown" ]; then
        echo -e "\033[1;34mDetected Distribution: $DISTRO\033[0m\n"
    else
        echo -e "\033[1;34mDetected Distribution: $DISTRO (Generic Linux)\033[0m\n"
    fi
}

# Function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to install a package based on the OS and available package manager
install_package() {
    PACKAGE_NAME=$1
    DESCRIPTION=$2

    echo -e "\033[1;33mAttempting to install '$PACKAGE_NAME' ($DESCRIPTION)...\033[0m"

    if [ "$OS" == "Linux" ]; then
        case "$DISTRO" in
            AmazonLinux|CentOS|Fedora|RedHatEnterpriseServer)
                if command_exists yum; then
                    sudo yum install -y "$PACKAGE_NAME"
                elif command_exists dnf; then
                    sudo dnf install -y "$PACKAGE_NAME"
                else
                    echo -e "\033[1;31mError: Neither 'yum' nor 'dnf' package managers are available.\033[0m"
                    return 1
                fi
                ;;
            Ubuntu|Debian)
                if command_exists apt-get; then
                    sudo apt-get update && sudo apt-get install -y "$PACKAGE_NAME"
                else
                    echo -e "\033[1;31mError: 'apt-get' package manager is not available.\033[0m"
                    return 1
                fi
                ;;
            *)
                echo -e "\033[1;31mError: Unsupported Linux distribution for automatic installation.\033[0m"
                return 1
                ;;
        esac
    elif [ "$OS" == "Mac" ]; then
        if command_exists brew; then
            brew install "$PACKAGE_NAME"
        else
            echo -e "\033[1;33mHomebrew not found. Attempting to install Homebrew...\033[0m"
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            # Add Homebrew to PATH
            if [ -d "/opt/homebrew/bin" ]; then
                eval "$(/opt/homebrew/bin/brew shellenv)"
            elif [ -d "/usr/local/bin" ]; then
                eval "$(/usr/local/bin/brew shellenv)"
            fi
            if command_exists brew; then
                brew install "$PACKAGE_NAME"
            else
                echo -e "\033[1;31mError: Homebrew installation failed.\033[0m"
                return 1
            fi
        fi
    elif [ "$OS" == "Windows" ]; then
        # Attempt to use Chocolatey for Windows
        if command_exists choco; then
            choco install -y "$PACKAGE_NAME"
        else
            echo -e "\033[1;33mChocolatey not found. Attempting to install Chocolatey...\033[0m"
            # Install Chocolatey
            powershell.exe -NoProfile -InputFormat None -ExecutionPolicy Bypass -Command \
                "Set-ExecutionPolicy Bypass -Scope Process -Force; \
                [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; \
                iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))"
            # Reload environment
            export PATH="$PATH:/c/ProgramData/Chocolatey/bin"
            if command_exists choco; then
                choco install -y "$PACKAGE_NAME"
            else
                echo -e "\033[1;31mError: Chocolatey installation failed.\033[0m"
                return 1
            fi
        fi
    else
        echo -e "\033[1;31mError: Unsupported OS for automatic package installation.\033[0m"
        return 1
    fi

    # Verify installation
    if command_exists "$PACKAGE_NAME"; then
        echo -e "\033[1;32mSuccessfully installed '$PACKAGE_NAME'.\033[0m"
        return 0
    else
        echo -e "\033[1;31mFailed to install '$PACKAGE_NAME'.\033[0m"
        return 1
    fi
}

# Function to ensure required tools are installed
ensure_tool() {
    TOOL=$1
    PACKAGE=$2
    DESCRIPTION=$3

    if command_exists "$TOOL"; then
        echo -e "\033[1;32m$DESCRIPTION '$TOOL' is already installed.\033[0m"
    else
        echo -e "\033[1;33m$DESCRIPTION '$TOOL' is missing.\033[0m"
        install_package "$PACKAGE" "$DESCRIPTION"
        if [ $? -ne 0 ]; then
            echo -e "\033[1;31mError: Unable to install '$TOOL'. Some functionalities may not work.\033[0m"
        fi
    fi
}

# Function to perform System Information Discovery (T1082)
system_info_discovery() {
    echo -e "\033[1;32m=== System Information Discovery (T1082) ===\033[0m"
    if [ "$OS" == "Windows" ]; then
        if command_exists systeminfo; then
            echo -e "\033[1;36mExecuting 'systeminfo':\033[0m"
            systeminfo
        elif command_exists lshw; then
            echo -e "\033[1;36mExecuting 'lshw':\033[0m"
            lshw
        else
            # Attempt to install 'lshw' as fallback
            ensure_tool "lshw" "lshw" "Installing system information tool"
            if command_exists lshw; then
                echo -e "\033[1;36mExecuting 'lshw' after installation:\033[0m"
                sudo lshw
            else
                echo -e "\033[1;31mError: Neither 'systeminfo' nor 'lshw' is available.\033[0m"
            fi
        fi
    elif [ "$OS" == "Linux" ] || [ "$OS" == "Mac" ]; then
        echo -e "\033[1;36mExecuting 'uname -a':\033[0m"
        uname -a
        if command_exists lshw; then
            echo -e "\033[1;36mExecuting 'lshw':\033[0m"
            sudo lshw
        else
            # Attempt to install 'lshw'
            ensure_tool "lshw" "lshw" "Installing detailed hardware information tool"
            if command_exists lshw; then
                echo -e "\033[1;36mExecuting 'lshw' after installation:\033[0m"
                sudo lshw
            elif command_exists dmidecode; then
                echo -e "\033[1;36mExecuting 'dmidecode' as alternative:\033[0m"
                sudo dmidecode
            elif command_exists hwinfo; then
                echo -e "\033[1;36mExecuting 'hwinfo' as alternative:\033[0m"
                sudo hwinfo
            else
                echo -e "\033[1;33mWarning: No detailed hardware info tool found. Skipping detailed hardware info.\033[0m"
            fi
        fi
    else
        echo -e "\033[1;31mUnsupported OS for System Information Discovery.\033[0m"
    fi
    echo ""
}

# Function to perform System Owner / User Discovery (T1033)
user_discovery() {
    echo -e "\033[1;32m=== System Owner / User Discovery (T1033) ===\033[0m"
    echo -e "\033[1;36mExecuting 'whoami':\033[0m"
    whoami
    echo ""
    echo -e "\033[1;36mExecuting 'users':\033[0m"
    users
    echo ""
}

# Function to perform Account Discovery – Local Account (T1087.001)
local_account_discovery() {
    echo -e "\033[1;32m=== Account Discovery – Local Account (T1087.001) ===\033[0m"
    if [ "$OS" == "Windows" ]; then
        if command_exists net; then
            echo -e "\033[1;36mExecuting 'net localgroup administrators':\033[0m"
            net localgroup administrators
        else
            # Attempt to install 'net' via Chocolatey if possible
            echo -e "\033[1;33m'net' command not found. Attempting to install via Chocolatey...\033[0m"
            ensure_tool "net" "net" "Installing 'net' command tool"
            if command_exists net; then
                echo -e "\033[1;36mExecuting 'net localgroup administrators' after installation:\033[0m"
                net localgroup administrators
            else
                echo -e "\033[1;31mError: 'net' command is still not available.\033[0m"
            fi
        fi
    elif [ "$OS" == "Linux" ] || [ "$OS" == "Mac" ]; then
        if command_exists getent; then
            echo -e "\033[1;36mExecuting 'getent group sudo':\033[0m"
            getent group sudo
        else
            # Attempt to install 'getent' via appropriate package
            # On most systems, 'getent' is part of libc-bin or similar
            echo -e "\033[1;33m'getent' command not found. Attempting to install...\033[0m"
            case "$DISTRO" in
                Ubuntu|Debian)
                    ensure_tool "getent" "libc-bin" "Installing 'getent' command tool"
                    ;;
                Fedora|CentOS|AmazonLinux)
                    ensure_tool "getent" "glibc-common" "Installing 'getent' command tool"
                    ;;
                *)
                    echo -e "\033[1;31mError: Unsupported distribution for 'getent' installation.\033[0m"
                    ;;
            esac
            if command_exists getent; then
                echo -e "\033[1;36mExecuting 'getent group sudo' after installation:\033[0m"
                getent group sudo
            else
                echo -e "\033[1;31mError: 'getent' command is still not available.\033[0m"
            fi
        fi
    else
        echo -e "\033[1;31mUnsupported OS for Local Account Discovery.\033[0m"
    fi
    echo ""
}

# Function to perform System Network Configuration Discovery (T1016)
network_config_discovery() {
    echo -e "\033[1;32m=== System Network Configuration Discovery (T1016) ===\033[0m"
    
    # Network Interfaces
    if command_exists ip; then
        echo -e "\033[1;36mExecuting 'ip addr':\033[0m"
        ip addr
    elif command_exists ifconfig; then
        echo -e "\033[1;36mExecuting 'ifconfig':\033[0m"
        ifconfig
    else
        # Attempt to install 'iproute2' or 'net-tools'
        if [ "$OS" == "Linux" ]; then
            echo -e "\033[1;33mNeither 'ip' nor 'ifconfig' found. Attempting to install 'iproute2'...\033[0m"
            ensure_tool "ip" "iproute2" "Installing 'ip' command tool"
            if command_exists ip; then
                echo -e "\033[1;36mExecuting 'ip addr' after installation:\033[0m"
                ip addr
            else
                echo -e "\033[1;33mAttempting to install 'ifconfig' via 'net-tools'...\033[0m"
                ensure_tool "ifconfig" "net-tools" "Installing 'ifconfig' command tool"
                if command_exists ifconfig; then
                    echo -e "\033[1;36mExecuting 'ifconfig' after installation:\033[0m"
                    ifconfig
                else
                    echo -e "\033[1;31mError: Neither 'ip' nor 'ifconfig' commands are available.\033[0m"
                fi
            fi
        elif [ "$OS" == "Mac" ]; then
            # 'ifconfig' is usually available on macOS
            echo -e "\033[1;33m'ip' command not found. 'ifconfig' should be available on macOS.\033[0m"
        else
            echo -e "\033[1;31mUnsupported OS for Network Interface Discovery.\033[0m"
        fi
    fi
    echo ""
    
    # Routing Tables
    if command_exists netstat; then
        echo -e "\033[1;36mExecuting 'netstat -rn':\033[0m"
        netstat -rn
    elif command_exists route; then
        echo -e "\033[1;36mExecuting 'route -n':\033[0m"
        route -n
    elif command_exists ip; then
        echo -e "\033[1;36mExecuting 'ip route':\033[0m"
        ip route
    else
        # Attempt to install 'net-tools' or 'iproute2'
        if [ "$OS" == "Linux" ]; then
            echo -e "\033[1;33mNo routing commands found. Attempting to install 'net-tools'...\033[0m"
            ensure_tool "netstat" "net-tools" "Installing 'netstat' command tool"
            if command_exists netstat; then
                echo -e "\033[1;36mExecuting 'netstat -rn' after installation:\033[0m"
                netstat -rn
            elif command_exists route; then
                echo -e "\033[1;36mExecuting 'route -n' after installation:\033[0m"
                route -n
            elif command_exists ip; then
                echo -e "\033[1;36mExecuting 'ip route' after installation:\033[0m"
                ip route
            else
                echo -e "\033[1;31mError: No suitable command found for routing information.\033[0m"
            fi
        elif [ "$OS" == "Mac" ]; then
            # 'netstat' and 'route' are usually available on macOS
            echo -e "\033[1;33mNo fallback available for macOS. Please ensure 'netstat' or 'route' is installed.\033[0m"
        else
            echo -e "\033[1;31mUnsupported OS for Routing Table Discovery.\033[0m"
        fi
    fi
    echo ""
    
    # Network Shares
    if [ "$OS" == "Windows" ]; then
        if command_exists net; then
            echo -e "\033[1;36mExecuting 'net share':\033[0m"
            net share
        elif command_exists wmic; then
            echo -e "\033[1;36mExecuting 'wmic share get Name, Path':\033[0m"
            wmic share get Name, Path
        else
            # Attempt to install 'net' via Chocolatey
            echo -e "\033[1;33m'net' command not found. Attempting to install via Chocolatey...\033[0m"
            ensure_tool "net" "net" "Installing 'net' command tool"
            if command_exists net; then
                echo -e "\033[1;36mExecuting 'net share' after installation:\033[0m"
                net share
            else
                echo -e "\033[1;31mError: 'net' command is still not available.\033[0m"
            fi
        fi
    elif [ "$OS" == "Linux" ] || [ "$OS" == "Mac" ]; then
        if command_exists df; then
            echo -e "\033[1;36mExecuting 'df -h':\033[0m"
            df -h
        else
            # Attempt to install 'coreutils'
            if [ "$OS" == "Linux" ]; then
                ensure_tool "df" "coreutils" "Installing 'df' command tool"
                if command_exists df; then
                    echo -e "\033[1;36mExecuting 'df -h' after installation:\033[0m"
                    df -h
                else
                    echo -e "\033[1;31mError: 'df' command is still not available.\033[0m"
                fi
            elif [ "$OS" == "Mac" ]; then
                # 'df' is usually available on macOS
                echo -e "\033[1;33m'df' command not found on macOS. Please ensure 'df' is installed.\033[0m"
            else
                echo -e "\033[1;31mUnsupported OS for Network Share Discovery.\033[0m"
            fi
        fi
    fi
    echo ""
}

# Function to perform Remote System Discovery (T1018)
remote_system_discovery() {
    echo -e "\033[1;32m=== Remote System Discovery (T1018) ===\033[0m"
    if [ "$OS" == "Windows" ]; then
        if command_exists net; then
            echo -e "\033[1;36mExecuting 'net group \"Domain Computers\" /domain':\033[0m"
            net group "Domain Computers" /domain
            if [ $? -ne 0 ]; then
                echo -e "\033[1;33m'net group' command failed. Attempting to use WMIC as fallback.\033[0m"
                if command_exists wmic; then
                    echo -e "\033[1;36mExecuting 'wmic computersystem get name':\033[0m"
                    wmic computersystem get name
                else
                    echo -e "\033[1;31mError: No suitable command found for remote system discovery.\033[0m"
                fi
            fi
        else
            echo -e "\033[1;33m'net' command not found. Attempting to install via Chocolatey...\033[0m"
            ensure_tool "net" "net" "Installing 'net' command tool"
            if command_exists net; then
                echo -e "\033[1;36mExecuting 'net group \"Domain Computers\" /domain' after installation:\033[0m"
                net group "Domain Computers" /domain
            else
                echo -e "\033[1;31mError: 'net' command is still not available.\033[0m"
            fi
        fi
    elif [ "$OS" == "Linux" ] || [ "$OS" == "Mac" ]; then
        if command_exists nmap; then
            echo -e "\033[1;36mScanning local network for active hosts with 'nmap -sn 192.168.1.0/24':\033[0m"
            nmap -sn 192.168.1.0/24
        elif command_exists arp-scan; then
            echo -e "\033[1;36mScanning local network for active hosts with 'arp-scan --localnet':\033[0m"
            sudo arp-scan --localnet
        else
            # Attempt to install 'nmap' or 'arp-scan'
            if [ "$OS" == "Linux" ]; then
                echo -e "\033[1;33mNo network scanning tools found. Attempting to install 'nmap'...\033[0m"
                ensure_tool "nmap" "nmap" "Installing 'nmap' network scanning tool"
                if command_exists nmap; then
                    echo -e "\033[1;36mExecuting 'nmap -sn 192.168.1.0/24' after installation:\033[0m"
                    nmap -sn 192.168.1.0/24
                else
                    echo -e "\033[1;33mAttempting to install 'arp-scan' as alternative...\033[0m"
                    ensure_tool "arp-scan" "arp-scan" "Installing 'arp-scan' network scanning tool"
                    if command_exists arp-scan; then
                        echo -e "\033[1;36mExecuting 'arp-scan --localnet' after installation:\033[0m"
                        sudo arp-scan --localnet
                    else
                        echo -e "\033[1;33mNo network scanning tools available. Skipping remote system discovery.\033[0m"
                        echo "Consider installing 'nmap' or 'arp-scan' using your package manager."
                    fi
                fi
            elif [ "$OS" == "Mac" ]; then
                echo -e "\033[1;33mNo network scanning tools found on macOS. Skipping remote system discovery.\033[0m"
                echo "Consider installing 'nmap' using Homebrew:\033[0m"
                echo "brew install nmap"
            else
                echo -e "\033[1;31mUnsupported OS for Remote System Discovery.\033[0m"
            fi
        fi
    else
        echo -e "\033[1;31mUnsupported OS for Remote System Discovery.\033[0m"
    fi
    echo ""
}

# Function to perform Password Policy Discovery (T1201)
password_policy_discovery() {
    echo -e "\033[1;32m=== Password Policy Discovery (T1201) ===\033[0m"
    if [ "$OS" == "Windows" ]; then
        if command_exists net; then
            echo -e "\033[1;36mExecuting 'net accounts':\033[0m"
            net accounts
        elif command_exists wmic; then
            echo -e "\033[1;36mExecuting 'wmic path Win32_PasswordPolicy get /format:list':\033[0m"
            wmic path Win32_PasswordPolicy get /format:list
        else
            echo -e "\033[1;33m'net' command not found. Attempting to install via Chocolatey...\033[0m"
            ensure_tool "net" "net" "Installing 'net' command tool"
            if command_exists net; then
                echo -e "\033[1;36mExecuting 'net accounts' after installation:\033[0m"
                net accounts
            else
                echo -e "\033[1;31mError: 'net' command is still not available.\033[0m"
            fi
        fi
    elif [ "$OS" == "Linux" ] || [ "$OS" == "Mac" ]; then
        if [ -f /etc/login.defs ]; then
            echo -e "\033[1;36mDisplaying local password policies from '/etc/login.defs':\033[0m"
            sudo cat /etc/login.defs
        else
            echo -e "\033[1;31mError: '/etc/login.defs' not found.\033[0m"
        fi
    else
        echo -e "\033[1;31mUnsupported OS for Password Policy Discovery.\033[0m"
    fi
    echo ""
}

# Function to perform Network Share Discovery (T1135)
network_share_discovery() {
    echo -e "\033[1;32m=== Network Share Discovery (T1135) ===\033[0m"
    if [ "$OS" == "Windows" ]; then
        echo -e "\033[1;36mAttempting to execute 'Invoke-ShareFinder' via PowerShell:\033[0m"
        if command_exists pwsh; then
            pwsh -Command "Import-Module PowerView; Invoke-ShareFinder"
            if [ $? -ne 0 ]; then
                echo -e "\033[1;33mFailed to execute 'Invoke-ShareFinder'. Ensure Veil-PowerView is installed.\033[0m"
            fi
        elif command_exists powershell; then
            powershell -Command "Import-Module PowerView; Invoke-ShareFinder"
            if [ $? -ne 0 ]; then
                echo -e "\033[1;33mFailed to execute 'Invoke-ShareFinder'. Ensure Veil-PowerView is installed.\033[0m"
            fi
        else
            echo -e "\033[1;31mError: PowerShell is not available.\033[0m"
        fi
    elif [ "$OS" == "Linux" ] || [ "$OS" == "Mac" ]; then
        if command_exists smbclient; then
            echo -e "\033[1;36mExecuting 'smbclient -L localhost -N':\033[0m"
            smbclient -L localhost -N
        elif command_exists nmblookup; then
            echo -e "\033[1;36mExecuting 'nmblookup -S *':\033[0m"
            nmblookup -S *
        else
            # Attempt to install 'smbclient'
            if [ "$OS" == "Linux" ]; then
                echo -e "\033[1;33mNo SMB client tools found. Attempting to install 'smbclient'...\033[0m"
                ensure_tool "smbclient" "smbclient" "Installing 'smbclient' SMB client tool"
                if command_exists smbclient; then
                    echo -e "\033[1;36mExecuting 'smbclient -L localhost -N' after installation:\033[0m"
                    smbclient -L localhost -N
                else
                    echo -e "\033[1;33mNo SMB client tools available. Skipping network share discovery.\033[0m"
                    echo "Consider installing 'smbclient' or 'nmblookup' using your package manager."
                fi
            elif [ "$OS" == "Mac" ]; then
                echo -e "\033[1;33mNo SMB client tools found on macOS. Attempting to install 'smbclient' via Homebrew...\033[0m"
                ensure_tool "smbclient" "smbclient" "Installing 'smbclient' SMB client tool"
                if command_exists smbclient; then
                    echo -e "\033[1;36mExecuting 'smbclient -L localhost -N' after installation:\033[0m"
                    smbclient -L localhost -N
                else
                    echo -e "\033[1;33mNo SMB client tools available. Skipping network share discovery.\033[0m"
                    echo "Consider installing 'smbclient' using Homebrew."
                fi
            else
                echo -e "\033[1;31mUnsupported OS for Network Share Discovery.\033[0m"
            fi
        fi
    else
        echo -e "\033[1;31mUnsupported OS for Network Share Discovery.\033[0m"
    fi
    echo ""
}

# Function to perform all discovery steps
perform_discovery() {
    echo -e "\033[1;35m=== Starting System Discovery ===\033[0m"
    detect_os
    system_info_discovery
    user_discovery
    local_account_discovery
    network_config_discovery
    remote_system_discovery
    password_policy_discovery
    network_share_discovery
    echo -e "\033[1;35m=== System Discovery Completed ===\033[0m"
}

# Execute the discovery
perform_discovery
