#!/bin/sh
# Luke's Auto Rice Boostrapping Script (LARBS) <https://github.com/LukeSmithxyz>
# adapted by Roger Webb <admin@abyssalvoid.xyz>
# License: GNU GPLv3

### OPTIONS AND VARIABLES ###

while getopts ":a:r:b:p:h" o; do case "${o}" in
	h) printf "Optional arguments for custom use:\\n  -r: Dotfiles repository (local file or url)\\n  -p: Dependencies and programs csv (local file or url)\\n  -h: Show this message\\n" && exit ;;
	r) dotfilesrepo=${OPTARG} && git ls-remote "$dotfilesrepo" || exit ;;
	b) repobranch=${OPTARG} ;;
	p) progsfile=${OPTARG} ;;
	*) printf "Invalid option: -%s\\n" "$OPTARG" && exit ;;
esac done

[ -z "$dotfilesrepo" ] && dotfilesrepo="https://github.com/ChickenParmigiana/voidrice.git"
[ -z "$progsfile" ] && progsfile="https://raw.githubusercontent.com/ChickenParmigiana/LARBS/master/progs.csv"
[ -z "$repobranch" ] && repobranch="master"

### FUNCTIONS ###

installpkg(){ xbps-install -y "$1" >/dev/null 2>&1 ;}
grepseq="\"^[PGV]*,\""

error() { clear; printf "ERROR:\\n%s\\n" "$1"; exit;}

welcomemsg() { \
	dialog --title "Welcome!" --msgbox "Void Linux, ChickenParm setup!\\n\\nGood Luck, Explorer!!\\n\\n-ChickenParm" 10 60
	}

getuser() { \
	# Prompts user for their username.
	name=$(dialog --inputbox "First, please the username you installed void with." 10 60 3>&1 1>&2 2>&3 3>&1) || exit
	repodir="/home/$name/repos"; sudo -u $name mkdir -p "$repodir"
	while ! echo "$name" | grep "^[a-z_][a-z0-9_-]*$" >/dev/null 2>&1; do
		name=$(dialog --no-cancel --inputbox "Username not valid. Be sure your username contains valid characters: lowercase letters, - or _." 10 60 3>&1 1>&2 2>&3 3>&1)
	done ;}

preinstallmsg() { \
	dialog --title "Enter The Void..." --yes-label "Warp!" --no-label "Abort Mission" --yesno "Blast-Off, just sit back and enjoy the ride.\\n\\nIt will take some time.\\n\\nNow just <Warp!> and the system will begin launch!" 13 60 || { clear; exit; }
	}

maininstall() { # Installs all needed programs from main repo.
	dialog --title "Warping, Roast Chicken" --infobox "Cataloging stars" \`$1\` ($n of $total). $1 $2" 5 70
	installpkg "$1"
	}

gitmakeinstall() {
	progname="$(basename "$1")"
	dir="$repodir/$progname"
	dialog --title "LARBS Installation" --infobox "Installing \`$progname\` ($n of $total) via \`git\` and \`make\`. $(basename "$1") $2" 5 70
	sudo -u "$name" git clone --depth 1 "$1" "$dir" >/dev/null 2>&1 || { cd "$dir" || return ; sudo -u "$name" git pull --force origin master;}
	cd "$dir" || exit
	make >/dev/null 2>&1
	make install >/dev/null 2>&1
	cd /tmp || return ;}

pipinstall() { \
	dialog --title "LARBS Installation" --infobox "Installing the Python package \`$1\` ($n of $total). $1 $2" 5 70
	command -v pip || installpkg python-pip >/dev/null 2>&1
	yes | pip install "$1"
	}

installationloop() { \
	([ -f "$progsfile" ] && cp "$progsfile" /tmp/progs.csv) || curl -Ls "$progsfile" | sed '/^#/d' | eval grep "$grepseq" > /tmp/progs.csv
	total=$(wc -l < /tmp/progs.csv)
	while IFS=, read -r tag program comment; do
		n=$((n+1))
		echo "$comment" | grep "^\".*\"$" >/dev/null 2>&1 && comment="$(echo "$comment" | sed "s/\(^\"\|\"$\)//g")"
		case "$tag" in
			"G") gitmakeinstall "$program" "$comment" ;;
			"P") pipinstall "$program" "$comment" ;;
			*) maininstall "$program" "$comment" ;;
		esac
	done < /tmp/progs.csv ;}

putgitrepo() { # Downloads a gitrepo $1 and places the files in $2 only overwriting conflicts
	dialog --infobox "Downloading and installing config files..." 4 60
	[ -z "$3" ] && branch="master" || branch="$repobranch"
	dir=$(mktemp -d)
	[ ! -d "$2" ] && mkdir -p "$2"
	chown -R "$name:wheel" "$dir" "$2"
	sudo -u "$name" git clone -b "$branch" --depth 1 "$1" "$dir" >/dev/null 2>&1
	sudo -u "$name" cp -rfT "$dir" "$2"
	}

finalize(){ \
	dialog --infobox "Preparing welcome message..." 4 50
	dialog --title "Done!" --msgbox "Congrats! Provided there were no hidden errors, we\'re in.\\n\\nTo run the new graphical environment, re-log and startx.\\n\\n - ChickenParm" 12 80
	}

### THE ACTUAL SCRIPT ###

### This is how everything happens in an intuitive format and order.

# Check if user is root on Arch distro. Install dialog.
installpkg dialog || error "Are you sure you're running this as the root user and have an internet connection?"

# Welcome user and pick dotfiles.
welcomemsg || error "User exited."

# Get and verify username and password.
getuser || error "User exited."

# Last chance for user to back out before install.
preinstallmsg || error "User exited."

dialog --title "LARBS Installation" --infobox "Installing \`Void nonfree repo\`, \`basedevel\` and \`git\`. These are required for the installation of other software." 5 70
installpkg void-repo-nonfree
xbps-install -Su >/dev/null
installpkg base-devel
installpkg git
installpkg curl

# The command that does all the installing. Reads the progs.csv file and
# installs each needed program using either xbps or git.
installationloop

# Install the dotfiles in the user's home directory
putgitrepo "$dotfilesrepo" "/home/$name" "$repobranch"

# Make zsh the default shell for the user
chsh -s /bin/zsh $name

# Fix firefox's problem rendering fonts with antialiasing
ln -s /usr/share/fontconfig/conf.avail/70-no-bitmaps.conf /etc/fonts/conf.d/70-no-bitmaps.conf

# Enable services
ln -s /etc/sv/cronie /var/service/
ln -s /etc/sv/isc-ntpd /var/service/

# Disable ttys 3-6
rm /var/service/agetty-tty6
touch /etc/sv/agetty-tty6/down
rm /var/service/agetty-tty5
touch /etc/sv/agetty-tty5/down
rm /var/service/agetty-tty4
touch /etc/sv/agetty-tty4/down
rm /var/service/agetty-tty3
touch /etc/sv/agetty-tty3/down

# Create basic home directories
sudo -u $name mkdir /home/$name/Documents /home/$name/Downloads /home/$name/Pictures/ /home/$name/Pictures/screenshots /home/$name/Videos /home/$name/Music

# Last message! Install complete!
finalize
clear
