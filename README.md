# sysadmin-toolbox
Linux scripts toolbox for helping a sysadmin on his day work.

These tools are created under no warranty nor responsability. Use them by your own.

## Tools Descriptions

### System utilities
- **lscom** -- is a simple script to list each COM interface connected to the system. If a COM interface is connected through USB, print the device too.

### Network utilities
- **checkip** -- monitorize a given IP using ICMP ping to show if destination is *alive* or *dead*. Execute a loop interactively to show its current state.

- **checknet** -- inspec a given network in CIDR notation to check (using ping) which IPs are on use.

### Terminal utilities and functions
- **clize** -- Tool to colorize the output of a given command using regex rules.

#### Functions tlabel.sh
This script, meant to be sourced, load following functions onto your terminal sessions.

- **tlabel** -- Creates a label on the upper right corner of the terminal with the dessired text to help identify it pourpose. Also changes the terminal title with the same text.

- **thead** -- Creates a header on the terminal (first line) with a given text for terminal identification. Also changes the terminal window title.

- **ttitle** -- Changes the terminal window title with the given text.
