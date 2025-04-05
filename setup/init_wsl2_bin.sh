#!/bin/bash
#
# WSL2 bin initialization script
# - This script will create symlinks to windows executables in the user's .wsl2/bin directory
# - This script exists because I dont want tons of dll's and other garbage in my path when autocomplete is enabled
#
WIN_WINDIR=${WIN_WINDIR:-/mnt/c/Windows}
WSLUTIL_DIR=${WSLUTIL_DIR:-"${HOME}/.wslutil"}
XDG_CACHE_HOME=${XDG_CACHE_HOME:-"${HOME}/.cache"}
WIN_PROGRAMFILES=${WIN_PROGRAMFILES:-"/mnt/c/Program Files"}
WIN_PROGRAMFILES_X86=${WIN_PROGRAMFILES_X86:-"/mnt/c/Program Files (x86)"}

PROGRAMS="${XDG_CACHE_HOME}/wslutil/programs"
mkdir -p "$(dirname $PROGRAMS)"
#rm -f $PROGRAMS # Remove cache
# Clear out the programs file if it older than 1 day (Cached for dev/debugging)
if [[ -f $PROGRAMS ]]; then
    if [[ $(find $PROGRAMS -mtime +1) ]]; then
        rm -f $PROGRAMS
    fi
fi
# Create the programs file if it does not exist
if [[ ! -f $PROGRAMS ]]; then
    # Faster to build up a list of programs and then search for them invdividually
    find "${WIN_PROGRAMFILES}" -type f -iname "*.exe" 2> /dev/null >> $PROGRAMS
    find "${WIN_PROGRAMFILES_X86}" -type f -iname "*.exe" 2> /dev/null >> $PROGRAMS
fi
# Variables to make this complete standalone
cmd_func() { "${WIN_WINDIR:-/mnt/c/Windows}/System32/cmd.exe" /c $@; }

EXES="$(
    sed -e 's/#.*$//g' << EOF | sort -u
# Windows Built In
# - These are the default windows commands that I want to be able to run from WSL
# - Beware though that file arguments may not work as expected unless you use the windows path
explorer.exe
msedge.exe
cmd.exe
powerShell.exe       # Used a slightly different name to avoid handling in git-browse
SUDO.exe
ipconfig.exe
netsh.exe
reg.exe
regedit.exe
notepad.exe
systeminfo.exe
taskkill.exe
tasklist.exe
taskmgr.exe

# Windows Extras
# - Generally for gui apps just utilize win-open <file> to open the file in the default app
# - Dont put applications like Word/Excel/Acrobat in here unless you dont want to use the default app
curl.exe             # Sometimes used to test network connectivity & proxy
winget.exe           # Doesnt work right due to needing elevated permissions for changes
wt.exe
wsl.exe
gsudo.exe            # gsudo is a sudo replacement for windows that theoretically works with wsl
powertoys.awake.exe
notepad++.exe
brave.exe
librewolf.exe
firefox.exe
chrome.exe
EOF
)"
#
# Add any windows commands that are in the path that you want easily accessible here
for i in ${EXES}; do
    # Search first for the exe in the default windows path in order to preserve any PATH ordering prefernces
    exe="$(wslpath $(cmd_func "where $i" 2> /dev/null | strings | head -1) 2> /dev/null)"

    # If not found search recursively in the program files directories and select the first one found
    # TODO: Probably should warn if more than one is found
    if [[ ! "$?" == "0" ]]; then
        exe=$(grep -i "/$i" $PROGRAMS 2> /dev/null | head -1)
    fi

    if [[ -f "$exe" ]]; then
        #base=$(basename "$exe")
        base=$i
        if [[ -L "${WSLUTIL_DIR}/bin/${base}" && ! -e "${WSLUTIL_DIR}/bin/${base}" ]]; then
            echo "WARN: Deleting bad symlink ${WSLUTIL_DIR}/bin/${base}"
            rm -f "${WSLUTIL_DIR}/bin/${base}"
        fi
        if [[ ! -L "${WSLUTIL_DIR}/bin/${base}" ]]; then
            echo "DONE: Linked ${exe} to ${WSLUTIL_DIR}/bin/${base}"
            #ln -s "$exe" ${WSLUTIL_DIR}/bin/${base%%.exe}
            ln -s "$exe" "${WSLUTIL_DIR}/bin/${base}"
        fi
    else
        echo "WARN: Unable to find \"$i\" in path"
    fi
done

#
# Add any full path windows commands that you want easily accessible here that are not from program files, perhaps from the user profile
#
# Note: Some gui applications may not work as expected without disowning processes and redirecting output from stdout/stderr
#

# for exe in ""; do
#     if [[ -f "$exe" ]]; then
#         base=$(basename "$exe")
#         if [[ ! -L ${WSLUTIL_DIR}/bin/${base} ]]; then
#             echo "DONE: Linked $exe to ${WSLUTIL_DIR}/bin/"
#             #ln -s "$exe" ${WSLUTIL_DIR}/bin/${base%%.exe}
#             ln -s "$exe" ${WSLUTIL_DIR}/bin/${base}
#         fi
#     else
#         echo "WARN: Unable to find \"$exe\""
#     fi
# done

#
# Special case handling for shell scripts hosted in windows but expected to run in WSL
for exe in "${WIN_PROGRAMFILES}/Microsoft VS Code/bin/code" "${WIN_USERPROFILE}/AppData/Local/Programs/Microsoft VS Code Insiders/bin/code-insiders"; do
    if [[ -f "$exe" ]]; then
        base=$(basename "$exe")
        if [[ ! -L ${WSLUTIL_DIR}/bin/${base} ]]; then
            echo "DONE: Linked $exe to ${WSLUTIL_DIR}/bin/"
            ln -s "$exe" ${WSLUTIL_DIR}/bin/${base}
        fi
    else
        echo "WARN: Unable to find \"$exe\""
    fi
done
