#!/bin/bash

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2.

# This script automates starting Floppix. This script only works when Floppix
# is run in Bochs. The 'command-mode' patch must to be applied to Bochs.
#
# This is a simplistic expect-like script. It swaps floppies, answers
# prompts, and logs-in to Floppix.
#
# The script works by periodically taking screenshots of the Bochs window,
# (which are saved in text format) and examining the last line of text of the
# screen. When the last line matches an expected value, simulated keypresses
# are sent to the Bochs window in order to answer the prompt.
#
# This script can be stopped and re-started while Floppix is starting up. In
# most (but not all) cases, this script will be able to continue answering
# Floppix prompts whenever needed. This feature can be used to supply
# custom/different answers than what this script provides. For best results
# edit this script to provide your answers. Alteratively, comment out the
# automated prompt and answer. When the Floppix prompt appears, supply your
# own answer(s) and then this script will resume auto-answering prompts.
# This script does not need to be stopped while you are answering.


set -e



# User name.
USER_NAME="J. Doe"

# Login name. Max of five letters/digits.
USER_INITIALS=jd

# Login password. Due to automation issues, the password might appear on screen.
USER_PASSWORD=secret

# Substring of title of window running Bochs. Edit as needed.
BOCHS_WINDOW_TITLE="Bochs x86-64 emulator"











WID=
BOCH_WID=
SNAP_WID=
SNAPSHOT_FILE="snapshot.txt"
PROMPT_LINE=
DISK_NUM=1
CMD_KEY=F7


ANS_ROOTDISK=0
ANS_BOOTDISK=0
ANS_USR_CREATED=0
ANS_NAME=0
ANS_INITIALS=0
ANS_PASSWORD1=0
ANS_PASSWORD2=0
ANS_NET_CONFIG=0
ANS_PRINTER=0
ANS_SAVE_CONFIG=0
ANS_REMOVE_BOOT=0
ANS_LOGIN=0
#ANS_PASSWORD3=0



find_window() {
    local title="$1"

    local i=0
    while true; do

        set +e
        WID="$(xdotool search  --onlyvisible --name "$title")"
        set -e

        if [ ! "$WID" = "" ]; then
            if [ "$(printf "$WID\n" | wc -l )" -gt 1 ]; then
                printf "Multiple windows found for title. Exiting.\n"
                exit 1
            fi
            return
        fi

        i=$(( $i + 1 ))
        if [ "$i" -gt 5 ]; then
          printf "Failed to find window with title: '$title'\n"
          exit 1
        fi

        sleep 4
    done
}


find_bochs_window() {
    find_window "$BOCHS_WINDOW_TITLE"
    BOCHS_WID=$WID
}


find_snapshot_window() {
    snapshot_window_title="Save snapshot as..."
    find_window "$snapshot_window_title"
    SNAP_WID=$WID
}


take_snapshot() {
    rm -f "$SNAPSHOT_FILE"
    rm -f "$SNAPSHOT_FILE?" # Remove malformed name, which is sometimes created.
    
    find_bochs_window
    xdotool windowactivate --sync $BOCHS_WID key --delay 100 $CMD_KEY s

    find_snapshot_window
    xdotool windowactivate --sync $SNAP_WID key --delay 100 Return

    if [ ! -e "$SNAPSHOT_FILE" ]; then
        printf "Failed to create snapshot\n"
        exit 1
    fi
}


work_around_bug() {
    # For some reason, the first alphabetic character (i.e. not numbers or
    # Function keys) sent by xdotool is wrong. Once the initial 'bad' character
    # is sent, all other chars are sent correctly.
    # On my machine, sending a 'j' will actually send a 'c' to Bochs.
    # I susupect that this issue may be due to the keymap that I use.
    find_bochs_window
    xdotool windowactivate --sync $BOCHS_WID key $CMD_KEY j
}


open_bochs_config() {
    xdotool windowactivate --sync $BOCHS_WID key $CMD_KEY f
}


close_bochs_config() {
    xdotool windowactivate --sync $BOCHS_WID type --delay 100 "$(printf "9\r")"
}


insert_disk1() {
    if [ ! "$DISK_NUM" = 1 ]; then
        open_bochs_config
        xdotool windowactivate --sync $BOCHS_WID type --delay 100 "$(printf "1\r./floppix/disk1.img\r\r\r\r")"
        close_bochs_config
        DISK_NUM=1
    fi
}


insert_disk2() {
    if [ ! "$DISK_NUM" = 2 ]; then
        open_bochs_config
        xdotool windowactivate --sync $BOCHS_WID type --delay 100 "$(printf "1\r./floppix/disk2.img\r\r\r\r")"
        close_bochs_config
        DISK_NUM=2
    fi
}


remove_floppy() {
    open_bochs_config
    xdotool windowactivate --sync $BOCHS_WID type --delay 100 "$(printf "1\rnone\r")"
    close_bochs_config
}


is_last_line_blank() {
    # When last line of snapshot.txt is 'blank', it actually has a 0xdf char.
    # Octal '\337' == Hex '0xdf'.
    test "$(tail $SNAPSHOT_FILE -n 1 | tr '\337' ' ')" = " "
}


get_prompt_line() {
    if [ "$(cat $SNAPSHOT_FILE | wc -l)" -eq 25 ]; then
        local lines=1
        if is_last_line_blank; then
            lines=2
        fi
        printf -- "$(tail -n $lines $SNAPSHOT_FILE | head -n 1)"
    fi
}


send_text() {
    txt="$1"
    xdotool windowactivate --sync $BOCHS_WID type --delay 100 "$(printf "$txt")"
}


send_enter() {
    send_text "\r"
}


# Simulates a test-and-set-lock operation.
# A bit of bash magic that checks and sets a varible name by reference.
# If the variable value is 0, then set value to 1 and return 0.
# Otherwise return 1.
tsl() {
   local varnam="$1"
   if [ ${!varnam} -eq 0 ]; then # Read value by reference.
      read $varnam <<< 1 # Use heredoc to Set value (to 1) by reference.
      return 0
   fi
   return 1
}


is_prompt() {
    printf -- "$PROMPT_LINE" | grep -q "$1"
}


if [ "$1" = "clean" ]; then
    rm -rf floppix
    rm -f "$SNAPSHOT_FILE"
    rm -f "$SNAPSHOT_FILE?" # Removes malformed snapshots, that sometimes occur.
    rm -f bochsout.txt
    exit 0
fi

if [ ! -f ./bochs-2.6.11/bochs ]; then
    printf "Bochs does not appear to be built\n"
    exit 1
fi

# Unpack Floppix.
if [ ! -f ./floppix/disk1.img ] || [ ! -f ./floppix/disk2.img ]; then
  tar --overwrite -xzf floppix.tar.gz
fi


printf "\n"
printf "         Attempting to auto-answer Floppix prompts.\n"
printf "\n"
printf "While Floppix is starting up, this script can be stopped (with Ctrl-C) and\n"
printf "re-started and, in most cases, will resume without issue.\n"

work_around_bug


while true; do
    sleep 1  # Help prevent busy loops
    take_snapshot

    PROMPT_LINE="$(get_prompt_line)"

    if is_prompt "Unable to open an initial console."; then
       printf "Error: Failed to open console. Restarting the script will not be able to continue.\n"
       exit 1
    fi
    
    if is_prompt "invalid compressed format (err=1)"; then
       printf "Error: Invalid compressed format. Restarting the script will not be able to continue.\n"
       exit 1
    fi
    
    if is_prompt "VFS: Insert root floppy disk to be loaded into ramdisk and press ENTER"; then
       if tsl ANS_ROOTDISK; then
           insert_disk2
           send_enter
       fi
       continue
    fi

    if is_prompt "Please insert boot disk (disk 1); press \[enter\] key when ready"; then
        if tsl ANS_BOOTDISK; then
            insert_disk1
            send_enter
        fi
        continue
    fi

    if is_prompt "/usr created.  Press \[enter\] to continue"; then
        if tsl ANS_USR_CREATED; then
            send_enter
        fi
        continue
    fi

    if is_prompt "Enter your name: ()"; then
        if tsl ANS_NAME; then
            send_text "$USER_NAME\r"
        fi
        continue
    fi

    if is_prompt "Enter your initials; up to 5 letters/digits:"; then
        if tsl ANS_INITIALS; then
            send_text "$USER_INITIALS\r"
        fi
        continue
    fi

    if is_prompt "Make up a password for floppix (it will not appear on the screen):"; then
        if tsl ANS_PASSWORD1; then
            send_text "$USER_PASSWORD\r"
        fi
        continue
    fi

    if is_prompt "Re-enter password:"; then
        if tsl ANS_PASSWORD2; then
            send_text "$USER_PASSWORD\r"
        fi
        continue
    fi

    if is_prompt "Select option \[1, 2, 3, 4\]:"; then
        if tsl ANS_NET_CONFIG; then
            send_text "1\r"
        fi
        continue
    fi

    if is_prompt "Do you want to enable printing to a parallel port printer? (n)"; then
        if tsl ANS_PRINTER; then
            send_enter
        fi
        continue
    fi

    if is_prompt "Save configuration on floppix boot disk? (y/n)"; then
        if tsl ANS_SAVE_CONFIG; then
            send_text "n\r"
        fi
        continue
    fi

    if is_prompt "You may remove the boot diskette now. Press \[enter\] to continue."; then
        if tsl ANS_REMOVE_BOOT; then
            remove_floppy
            send_enter
        fi
        continue
    fi

    if is_prompt "floppix$USER_INITIALS login:"; then
        if tsl ANS_LOGIN; then
            # Send the login and password in a single string.
            # After the login is entered, Floppix will prompt for a password.
            # The user has 60 seconds to type in their password. If 60 seconds
            # expires, the screen will reset and re-prompt for a username.
            # When Bochs is run at full speed emulation, the time to
            # enter the password is reduced to two seconds or less (depending
            # on the speed of your machine).
            # The password might be visible on the screen.
            send_text "$USER_INITIALS\r$USER_PASSWORD\r"
        fi
        continue
    fi

    # This is commented out becouse the password is sent at the login prompt. 
    # if is_prompt "Password:"; then
    #    if tsl ANS_PASSWORD3; then
    #         send_text "$USER_PASSWORD\r"
    #    fi
    #     continue
    # fi

    if is_prompt "\\$"; then
        printf "Done.\n"
        exit 0
    fi

    sleep 6
done
