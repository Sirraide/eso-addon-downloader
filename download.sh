#!/usr/bin/env bash
set -eu

done=1
total=0
failed=()

deps_ptr=0
deps=()

err() {
	echo -e "\033[31m[$done / $total] Error: $1\033[m"
}

info() {
	echo -e "\033[33m[$done / $total] $1\033[m"
}

die() {
	echo -e "\033[31m$1\033[m"
	exit 1
}

perform_download() {
    local link
    local dlpage

    # Extract the download link.
    link="$(echo "$res" | htmlq a -a href | grep '/downloads/landing.php' | head -n1)"

    # Download the download page.
    info "Found \033[32m$1\033[33m at \033[32m$link\033[33m. Obtaining download link..."
    link="${link/ /%20}"
    dlpage="$(curl -L -s "https://www.esoui.com$link")"

    # Extract the download link.
    link="$(echo "$dlpage" | htmlq 'div.manuallink a' -a href)"
    link="${link/ /%20}"

    # Download the file.
    info "Downloading \033[32m$link\033[33m..."
    curl -L "$link" -O
}

download() {
	local res
	local link

    # Get the addon page.
    info "Searching for \033[32m$1\033[33m..."
    link="$1"
    link="${link/ /%20}"
	res="$(curl -L -s "https://www.esoui.com/downloads/search.php?search=$link")"

    # Perform the download if we're already on the addon's page.
    if echo "$res" | grep -P -m1 -q '/downloads/landing.php'; then
        perform_download "$1" "$res"
        return
    fi

    # Otherwise, the site may have returned a list of alternatives. Take the first one.
    if echo "$res" | grep -P -m1 -q 'class="alt1"'; then
        info "Search returned multiple results. Using the first one..."
        res="$(echo "$res" | htmlq '.alt1 a' -a href | head -n 1)"
        res="${res/ /%20}"
        res="$(curl -L -s "https://www.esoui.com/downloads/$res")"

        perform_download "$1" "$res"
        return
    fi

    err "Could not find \033[32m$1"
    failed+=("$1")
}

# Make sure we have a file to read addon names from.
if test $# -lt 1; then die "Usage:\033[33m $0\033[32m <file>"; fi
if ! test -f "$1"; then die "Not a valid path:\033[33m $1"; fi

# The directory for today's downloads.
d=$(date '+downloads %d-%m-%y')

# If the directory already exists, prompt the user if they want to overwrite it.
if test -e "./$d"; then
    echo -e -n "\033[33mDirectory \033[32m$d\033[33m already exists. Overwrite? (\033[32my\033[33m/\033[31mN\033[33m) \033[m"
    read yn
    case $yn in
        [Yy]* ) rm -rf "./$d" ;;
        * ) die "Aborted" ;;
    esac
fi

# Create the directory.
mkdir -p "./$d"

# Read the addon names from stdin.
addons=()
while IFS= read -r line; do addons+=("$line"); done < "$1"
total="${#addons[@]}"

# Print what we're downloading.
echo -e -n "\033[33mDownloading \033[34m$total\033[33m addons: "
for addon in "${!addons[@]}"; do
    if test "$addon" -ne 0; then echo -n ", "; fi
    echo -e -n "\033[32m${addons[$addon]}\033[33m";
done
echo -e "\033[m"

# Download each addon.
cd "./$d"
for addon in "${addons[@]}"; do
    download "$addon"
    done=$((done + 1))
done

# Unzip them and remove the zip files.
done=1
info "\033[33mUnzipping \033[34m$total\033[33m addons"
for z in *.zip*; do
    info "Unzipping \033[32m$z\033[33m..."
    unzip "$z"

    info "Removing \033[32m$z\033[33m..."
    rm "$z"

    done=$((done + 1))
done

# Print a summary.
info "\033[33mDone!\033[m"
info "\033[33m $((total - ${#failed[@]})) / $total addons downloaded successfully.\033[m"
if test ${#failed[@]} -gt 0; then
    echo -e -n "\033[31m[Error] Failed to download "
    for addon in "${!addons[@]}"; do
        if test "$addon" -ne 0; then echo -n ", "; fi
        echo -e -n "\033[32m${addons[$addon]}\033[31m";
    done
    echo -e "\033[m"
fi