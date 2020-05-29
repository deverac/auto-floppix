#!/bin/sh
# This script extracts the bochs-2.6.11.tar.gz source code, applies a patch,
# configures, and builds Bochs. Additional software and/or libraries may
# need to be installed before the build will succeed.
#
# The patch adds 'command-mode' to Bochs. Command-mode allows buttons in the
# headerbar to be activated by a key press. This feature is only implemented
# for the 'x' display_library.

set -e

# Prepare.
rm -rf bochs-2.6.11


# Extract source.
tar -xzf bochs-2.6.11.tar.gz


# Apply patch.
patch -p0 < command-mode.patch

# Configure and build.
cd bochs-2.6.11
./configure --enable-x86-64 && make
