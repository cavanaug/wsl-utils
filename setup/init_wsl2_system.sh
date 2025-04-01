sudo apt install binfmt-support
sudo cp ./WSLInterop.conf /usr/lib/binfmt.d/
sudo systemctl restart systemd-binfmt
sudo systemctl restart binfmt-support

win-browser --init
xdg-settings set default-web-browser win-browser.desktop
