#!/usr/bin/env bash
set -eu

done=1
total=0

die() {
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

    #link=$(echo "$res" | grep -P -m1 '/downloads/landing.php')
    #link=$(echo "$res" | sed -E 's|.*?<a href="(/downloads/landing\.php.*?)">.*|\1|')
    #link=$(perl '-MURI::Escape' -e 'print uri_unescape($ARGV[0])' "$link")

    # Extract the download link.
    link=$(echo "$res" | htmlq a -a href | grep '/downloads/landing.php' | head -n1)

    # Download the download page.
    info "Found \033[32m$1\033[33m at \033[32m$link\033[33m. Obtaining download link..."
    dlpage=$(curl -L -s "https://www.esoui.com$link")
    #echo "$dlpage" > dlpage.html # DEBUG

    # Extract the download link.
    link=$(echo "$dlpage" | htmlq 'div.manuallink a' -a href)

    # Download the file.
    info "Downloading \033[32m$link\033[33m..."
    curl -L "$link" -O
}

download() {
	local res

    # Get the addon page.
    info "Searching for \033[32m$1\033[33m..."
	res="$(curl -L -s "https://www.esoui.com/downloads/search.php?search=$1")"
    #echo "$res" > res.html # DEBUG

    # Perform the download if we're already on the addon's page.
    if echo "$res" | grep -P -m1 -q '/downloads/landing.php'; then
        perform_download "$1" "$res"
        return
    fi

    # Otherwise, the site may have returned a list of alternatives. Take the first one.
    if echo "$res" | grep -P -m1 -q 'class="alt1"'; then
        info "Search returned multiple results. Using the first one..."
        res="$(echo "$res" | htmlq '.alt1 a' -a href | head -n 1)"
        res=$(curl -L -s "https://www.esoui.com/downloads/$res")

        perform_download "$1" "$res"
        return
    fi

    err "Could not find \033[32m$1"
}


# Create a new directory for today's downloads.
d=$(date '+downloads %d-%m-%y')
mkdir -p "$d"
cd "$d"

# Read the addon names from stdin.
addons=()
while IFS= read -r line; do addons+=("$line"); done
total="${#addons[@]}"

# Print what we're downloading.
echo -e -n "\033[33mDownloading \033[34m$total\033[33m addons: "
for addon in "${!addons[@]}"; do
    if test "$addon" -ne 0; then echo -n ", "; fi
    echo -e -n "\033[32m${addons[$addon]}\033[33m";
done
echo -e "\033[m"

# Download each addon.
for addon in "${addons[@]}"; do
    download "$addon"
    done=$((done + 1))
done