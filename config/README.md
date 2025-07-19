# Configuration Settings

During the execution of 'wslutil setup' the following configuration files are used to merge settings into os and user configuration files.

## Winutil

wslutil.conf - configuration file for wslutil itseelf, primarily for setting symlinks in bin

## System & User configuration files

The utility crudini is used to merge these files and must be installed, 'wslutil doctor' checks for it

wsl.conf - This file is merged into /etc/wsl.conf
wslconfig - This file is merged into ${WIN_USERPROFILE}/.wslconfig
wslgconfig - This file is merged into ${WIN_USERPROFILE}/.wslgconfig
