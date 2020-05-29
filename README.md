# Auto-run Floppix in Bochs #

The [Floppix](http://floppix.com/) boot process requires answering prompts and
swapping floppy disks at various points. The `run-floppix.sh` script will
auto-answer the prompts, swap disks when necessary, and auto-login to Floppix.
It accomplishes this by periodically screen-scraping the Bochs window and
sending simulated keypresses to the Bochs window. For best results, the Bochs
window should have focus and you should avoid using other programs while
`run-floppix.sh` is running.

Script | Action
-------|----
`apply-patch.sh` | Extract [`bochs-2.6.11.tar.gz`](https://sourceforge.net/projects/bochs/files/bochs/2.6.11/bochs-2.6.11.tar.gz/download), apply the `command-mode.patch` patch file, configure, and build [Bochs](http://bochs.sourceforge.net/). Additional software and/or libraries may need to be installed for the build to succeed.
`run-floppix.sh` | Decompress `floppix.tar.gz`, and wait a moment for Bochs to start. `xdotool` must be installed.
`run-bochs.sh` | Start Bochs using `bochsrc.txt` as its configuration file.

In a terminal window, execute `./apply-patch.sh` and then execute
`./run-floppix.sh`. In a separate terminal window, execute `./run-bochs.sh`;
prior to executing you may need to set `BXSHARE` to tell Bochs where needed
files reside (e.g. `BXSHARE=/usr/share/bochs; export BXSHARE`). 

When answering Floppix prompts, the `run-floppix-sh` script supplies a user
name (__J. Doe__), login name (__jd__) and password (__secret__). If you wish
to use different values, the script must be edited.

If you wish to supply different answers than those provided by `run-floppy.sh`,
edit the script as needed. Alternatively, comment-out the desired
prompt/response in the script. When the Floppix boot process arrives at the
prompt, it will not be auto-answered by the script and you can manually enter
your answer(s). Once entered, `run-floppix.sh` will resume auto-answering
Floppix prompts.

`run-floppix.sh` expects the title of the Bochs window to contain the string
`Bochs x86-64 emulator`. Any changes to the title (such as when Bochs is
compiled for a 32-bit machine) will require updating the script.

`./run-floppix.sh clean` Removes all generated files, except the `bochs-2.6.11`
directory; the `bochs-2.6.11` directory must be removed manually.


### Bochs Command Mode Patch

The `command-mode.patch` file adds a _command-mode_ to Bochs.

In Bochs, the headerbar functions can only be activated via mouse. The
command-mode patch adds the ability to activate the headerbar functions via
the keyboard. The patch only implements this feature for the `x`
display_library.

When using `x` as the __display_library__, pressing the _F7_ key
will enter _command-mode_ and highlight the `F7=CMD` element in the statusbar;
the next key that is pressed will exit command-mode. When in command-mode,
if the pressed key is in the list below, the corresponding action will be
performed. With the exception of _F7_, any key pressed while in command-mode
will not be received by the program running in Bochs.

  Key | Action
  ----|---
 _z_  | Press the User button
 _c_  | Press the Copy button
 _p_  | Press the Paste button
 _s_  | Press the Snapshot button
 _f_  | Press the Config button
 _e_  | Press the Reset button
 _u_  | Press the Suspend button
 _w_  | Press the Power button
 _F7_ | Send an F7 keypress to the program running in Bochs

### Misc

By setting the `clock` value in `bochsrc.txt`, Bochs can be run at 'normal
speed' or 'accelerated speed'. When run at 'normal speed', at the login prompt
Floppix waits about 60 seconds to receive a password. If no password is
received, Floppix will reset the login screen. When Bochs is run at 'full
speed', the Floppix password prompt will timeout much faster. On my machine, it
takes less than two seconds. This makes entering a password challenging and
almost requires automating the login process.

Floppix cannot be run in [VirtualBox](https://www.virtualbox.org/). VirtualBox
requires floppy disk images to be structured in a particular way, however, the
Floppix `disk2.img` file contains a gzip-compressed filesystem
and does not conform to the 'normal' structure of a floppy disk image.

### License
Auto-floppix is released under the
[GPL v2 license](https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html).
This excludes Bochs (`bochs-2.6.11.tar.gz`) and Floppix (`floppix.tar.gz`)
files; they have their own licenses (which also happens to be GPL).
