CORE-Worm-Keylogger-CSCI-6531
==========
## Overview
This is an experiment/demo for CSCI 6531 Computer Security project on worms. The experiment features releasing a "worm" onto a [CORE](http://www.nrl.navy.mil/itd/ncs/products/core) (Common Open Network Emulator) simulated network. The worm propagates via SCP/SSH (assuming known passwords) and downloads and executes a keylogger in the background as its "payload."

The propagation mechanism is a shell script that scans the local subnet for available hosts using NMAP. Targets are then attacked by copying the propagation script to the target, logging in via SSH, downloading the keylogger, and then running the keylogger in the background before running the propagation script from the target.

The keylogger operates by monitoring the keyboard event driver under /dev/input.

## Features
The propagation script dynamically determines:
- The location of the keyboard driver under /dev/input
- The host's IP address, network mask, and connected ethernet interfaces (ethX)
- Hosts that are reachable under the direct subnet for available ethernet interfaces
- Hosts (on CORE) which are already infected with our keylogger.
- The location of each CORE host's .conf directory under /tmp/pycore.<num>/

The simple keylogger is able to capture keystrokes, even if the user is not interacting with it (ex. using their web browser).

## About CORE
[CORE](http://www.nrl.navy.mil/itd/ncs/products/core) allows a simple drag-and-drop GUI for quickly simulating a network. In our experiment, we use it to create multiple subnets of vulnerable hosts as well as a "server" to host our keylogger. 

One caveat of using CORE for this type of simulation is that each simulated host runs within the same filesystem as the true host (the VM). This means that all infected hosts actually log keys from the same keyboard. However, the keylogger will work fine under any Linux system which places a keyboard driver under /dev/input.

## Requirements
The propagation script uses mainly coreutils packages, expect for the following: nmap, expect

Additionally, in our CORE simulation, the keylogger is hosted on a server. This requires that apache2 package must be installed.

## Setup and Running
1. Set your [CORE VM](http://downloads.pf.itd.nrl.navy.mil/core/vmware-image/) to NAT in VirtualBox's network setting so that it can access the internet.
2. Start the CORE VM and update existing packages and download required packages:
  - Execute: `sudo apt-get update`
  - Execute: `sudo apt-get upgrade`
  - Execute: `sudo apt-get install expect nmap apache2 gcc`
  - Reboot
3. Download each of these files to your CORE VM and open projectNetwork.imn in CORE.
4. Set the root password to "core" (as this is what the propagation script uses by default for SCP/SSH)
  - Switch into root without knowing the current password -- execute: `sudo su -`
  - Execute: `passwd`
5. Compile logger.c and name the executable "logger":
  - Execute: `gcc logger.c -o logger`
6. Make propagate.sh executable:
  - Execute: `chmod +x propagate.sh`
7. Start the CORE simulation by pressing the green play button
8. Copy logger onto the Server:
  - Double-click the Server (10.0.3.10) to get its terminal
  - Execute: `cd var.www`
  - Execute: `cp <path-to-logger>/logger ./`
9. Double click any node where you want the worm to start (I just use N1)
  - `cd` to the directory where propagate.sh is (probably /home/core/Downloads)
  - Execute the propagation script and wait: `./propagate.sh`
    - Don't close the terminal until the propagation script is done (no more output is printed)
  - While worm propagates, you can open up other terminals or the browser and type text to be captured by the keyloggers.
10. To view progress / output:
  - Double click on any other node and ls to see the contents of their CORE directory
    - If the host is currently infected you will see propagate.sh and logger files
    - debug.txt: contains output from propagate.sh if the host has been infected
    - keylog.txt: contains output from the keylogger
    - infectedbyXX: the name of the host who infected this one
    - finished: when a host is done propagating to its neighbors it created a file called "finished" which contains a timestamp.
11. To rerun the demo: 
    - Press the red stop button to end the simulation. This deletes all files that were on the simulated hosts.
    - You need to remove the SSH known hosts file (or the entries for the CORE entities) or else propagate.sh will complain about the RSA fingerprints:
    - Execute (if you are only using the VM for CORE): `sudo rm /root/.ssh/known_hosts` or simply remove the entries for the CORE hosts' IPs.
    - Also, you will have to repeat step 8 and 9 every time you start the simulation.
