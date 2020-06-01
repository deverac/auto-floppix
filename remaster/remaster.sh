#!/bin/bash

# This script 'remasters' the two-disk Floppix distribution onto a single
# 2.88 Mb floppy image.
#
# Usage:
#    ./remaster.sh [ inst | mnt | cfg]
#
#    If run as a non-root user, you will be prompted to run other commands
#    as root.
#
# Remastering allows Floppix to easily be run in a Virtual Machines - just
# 'insert' the image as a floppy disk and boot the VM. In a VM
# the Floppix configuration file can be read and updated in the normal manner.
# If you have a machine with a USB port that can mimic a floppy drive, than
# the remastered Floppix can be run on real hardware by writing the remastered
# image to a USB stick and booting from the stick. 
#
# With the right software and a bit of work, the remastered Floppix image could
# also be run from a USB stick on a (real) machine that can not mimic a floppy
# drive. The Floppix configuration file would not be able to be saved, although
# a predefined one could be included in the remastered Floppix image.
# 
# Due to space constraints an 'old' version of SYSLINUX is required. The
# Floppix disk1.img used v1.48 and required 5,860 bytes on the disk; v2.00
# requires 7,836 bytes on the disk. Current versions of SYSLINUX require
# over 170 Kb. Incidentally, there is a problem with the SYSLINUX v1.48
# source code that nasm complains about and won't compile. (Too many 'org'
# statements.)
#
# Older versions of SYSLINUX require 'root' access in order to install the
# boot-code onto a disk image. Mounting and unmounting disk images also
# requires 'root' access. Running this script as 'root' will build a
# remastered Floppix image, but in order to minimize root operations, this
# script has been divided into separate parts - operations that require 'root'
# access, and operations that don't. When 'root' access is needed, the script
# will pause and prompt you to run certain commands as 'root'.


# When developing, set to 1 to 'cache' a bare-bones bootable floppy image, once
# it has been created. This avoids having to re-run syslinux, which requires
# 'root' access. This will also skip removing working files.
IS_DEVELOP=0


is_root() {
  test $(id -u) -eq 0
}

set -e

cmd="$1"

FD_NAME=floppix.img
FD_IMG=../$FD_NAME
WORK_DIR=work
DISK2_MOD=disk2mod.img


# Install syslinux. Root access is required.
if is_root && [ "$cmd" = "inst" ]; then
    cd $WORK_DIR
    # Older versions of syslinux require root access to install.
    /home/me/projects/syslnx/syslinux $FD_IMG
    exit 0
fi


# Populate new image with contents of disk2.img and add modifications. Root
# access is reoquired.
if is_root && [ "$cmd" = "mnt" ]; then
    cd $WORK_DIR
    mkdir d2
    mkdir rd

    # Mounting and unmounting images requires root.
    mount -o loop disk2.img d2/
    mount -o loop $DISK2_MOD rd/

    # Copy contents of disk2 to ramdisk. Preserve permissions (SUID bit).
    cp -r -p d2/* rd/

    # Overwrite mountfs with updated script.
    cp ../mods/mountfs ./rd/etc/init.d/
    chmod +x ./rd/etc/init.d/mountfs

    # Overwrite savecfg with updated script.
    cp ../mods/savecfg ./rd/etc/init.d/
    chmod +x ./rd/etc/init.d/savecfg

    # Store copy of ubin.
    mcopy -i disk1.img ::UBIN.TGZ ./rd/ubin.tgz # Change case.

    # Store copy usbin.
    mcopy -i disk1.img ::USBIN.TGZ ./rd/usbin.tgz # Change case.

    # Copy net modules (recursively).
    mcopy -s -i disk1.img ::/net ./rd

    # Copy pre-defined Floppix configuration.
    if [ -f ../floppix.cfg ]; then
        cp ../floppix.cfg ./rd/etc/
    fi

    # Create device so that 2.88Mb floppy disk can be read.
    mknod rd/dev/fd0u2880 b 2 32
    chmod 640 rd/dev/fd0u2880  # Match /dev/fd0

    # Remove to save space.
    rm -r rd/lost+found

    umount d2
    umount rd

    rmdir d2
    rmdir rd

    exit 0
fi


if [ "$cmd" = "cfg" ]; then
    printf "# Floppix config file.\n"
    printf "# See /etc/init.d/* files for how these are used. This is 'sourced'\n"
    printf "# in various scripts so unwanted/unused lines can be deleted.\n"
    printf "#userinitials\n"
    printf "NAME=''\n"
    printf "INITS=\n"
    printf "#fixed ip\n"
    printf "IPADDR=192.168.0.?\n"
    printf "NETMASK=255.255.255.0\n"
    printf "NETWORK=\n"
    printf "BROADCAST=\n"
    printf "GATEWAY=\n"
    printf "FDNS=\n"
    printf "FDOMAIN=\n"
    printf "#dialup\n"
    printf "COMPORT=1\n"
    printf "IRQ=\n"
    printf "IOPORT=\n"
    printf "MODEMINIT=\n"
    printf "PHONE1=xxx-xxxx\n"
    printf "USERNAME=\n"
    printf "DNS=xxx.xxx.xxx.xxx\n"
    printf "DOMAIN=xxx.com\n"
    printf "PAP=y\n"
    printf "#mail\n"
    printf "ADDR=userid@domain.com\n"
    printf "SMTP=\n"
    printf "POP3=\n"
    printf "LPIP=\n"
    exit 0
fi


if [ ! "$cmd" = "" ]; then
    printf "Error: Uknown or bad parameter.\n"
    printf "Usage:\n"
    printf "    $0 [ inst | mnt | cfg ]\n"
    printf "\n"
    printf "    cfg    Print an empty Floppix config file.\n"
    printf "    inst   Install syslinux into image.\n"
    printf "    mnt    Mount image and populate.\n"
    printf "\n"
    printf " The 'inst' and 'mnt' parameters should be supplied only when prompted\n"
    printf " to do so by this script. If 'floppix.cfg' exists, it will be copied into\n"
    printf " the remastered image.\n"
    printf "\n"
    printf " e.g. $0 cfg > floppix.cfg         # Edit as desired. (Optional)\n"
    printf "      $0                           # Remaster Floppix.\n"
    exit 1
fi

rm -rf $FD_NAME


rm -rf $WORK_DIR
tar -xzf ../floppix.tar.gz
mv floppix $WORK_DIR
cd $WORK_DIR


mv disk2.img disk2.img.gz # gunzip fails if extension is not gz.
gunzip disk2.img.gz


dev_img=../cache.img.dev
if [ -f $dev_img ]; then
    cp $dev_img $FD_IMG
else
    /sbin/mkfs.msdos -C $FD_IMG 2880 > /dev/null

    if is_root; then
        cd ..
        $0 inst
        cd $WORK_DIR
    else
        printf "\n"
        printf "  In another window, as 'root', execute \"$0 inst\".\n"
        printf "  After it completes press [Enter] to continue.\n"
        read
    fi

    if ! mdir -i $FD_IMG ::ldlinux.sys > /dev/null 2>&1; then
        printf "Syslinux does not appear to have been installed. Aborting.\n"
        exit 1
    fi

    if [ $IS_DEVELOP -eq 1 ]; then
        cp $FD_IMG $dev_img
    fi
fi



# Create new disk image.
dd if=/dev/zero of=$DISK2_MOD bs=8M count=1  > /dev/null 2>&1
/sbin/mkfs.ext2 -O none -m 0 $DISK2_MOD > /dev/null 2>&1

# Populate new disk image with Floppix disk2.img, and updates.
if is_root; then
    cd ..
    $0 mnt
    cd $WORK_DIR
else
    printf "\n"
    printf "  In another window, as 'root', execute \"$0 mnt\".\n"
    printf "  After it completes press [Enter] to continue.\n"
    read
fi

if ! e2ls -i $DISK2_MOD:bin > /dev/null 2>&1; then
    printf "Updating disk2 appears to have failed. Aborting.\n"
    exit 1
fi


printf "Compressing image..." # Exclude trailing newline.
# 7z compresses better than 'gzip -9'.
# Compressed sizes: gzip 2,567K; 7z 2,500K. About 67K difference.
#gzip -9 -c disk2mod.img > disk2mod.img.gz
7z a disk2mod.img.gz -mx=9 -tgzip $DISK2_MOD > /dev/null
printf "done.\n"





# Copy kernel to remastered image.
mcopy -i disk1.img ::linux .
mcopy -i $FD_IMG linux ::

# Copy floppix banner to remastered image.
mcopy -i disk1.img ::floppix.txt .
mcopy -i $FD_IMG floppix.txt ::

# Copy modified syslinux config to remastered image.
mcopy -i $FD_IMG ../mods/syslinux.cfg ::

# Copy compressed new disk image into remastered image. 'disk2r.img' is
# specified in syslinux.cfg.
mcopy -i $FD_IMG disk2mod.img.gz ::disk2r.img

# Clean up.
cd ..
if [ $IS_DEVELOP -eq 0 ]; then
    rm -r $WORK_DIR
fi

printf "Created $FD_NAME.\n"
