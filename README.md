# leapp_appimage_updater
Bash script to install and update Leapp Appimage. It also creates the menu entry.

This is strongly based (= shamelessy copied) on [Joplin](https://github.com/laurent22/joplin)'s install script. You can find it [here](https://github.com/laurent22/joplin/blob/dev/Joplin_install_and_update.sh)

# Installation
Just copy the script somewhere in your `$PATH` or just alias something like "leapp-update" to:
```
wget -O - https://raw.githubusercontent.com/pusi77/leapp_appimage_updater/main/leapp_install_and_update.sh | bash
```

# Usage
```
./leapp_install_and_update.sh <leapp_version>
```
Example:
```
./leapp_install_and_update.sh 0.12.0
```
