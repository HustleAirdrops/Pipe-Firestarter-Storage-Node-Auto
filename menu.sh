#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
BOLD='\033[1m'
CTRL_C_COUNT=0
IN_MENU=0

trap 'handle_ctrl_c' SIGINT

show_header() {
    clear
    echo -e "${BLUE}${BOLD}"
    echo "┌───────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐"
    echo "│  ██╗░░██╗██╗░░░██║░██████╗████████╗██╗░░░░░███████╗  ░█████╗░██╗██████╗░██████╗░██████╗░░█████╗░██████╗░░██████╗  │"
    echo "│  ██║░░██║██║░░░██║██╔════╝╚══██╔══╝██║░░░░░██╔════╝  ██╔══██╗██║██╔══██╗██╔══██╗██╔══██╗██╔══██╗██╔══██╗██╔════╝  │"
    echo "│  ███████║██║░░░██║╚█████╗░░░░██║░░░██║░░░░░█████╗░░  ███████║██║██████╔╝██║░░██║██████╔╝██║░░██║██████╔╝╚█████╗░  │"
    echo "│  ██╔══██║██║░░░██║░╚═══██╗░░░██║░░░██║░░░░░██╔══╝░░  ██╔══██║██║██╔══██╗██║░░██║██╔══██╗██║░░██║██╔═══╝░░╚═══██╗  │"
    echo "│  ██║░░██║╚██████╔╝██████╔╝░░░██║░░░███████╗███████╗  ██║░░██║██║██║░░██║██████╔╝██║░░██║╚█████╔╝██║░░░░░██████╔╝  │"
    echo "│  ╚═╝░░╚═╝░╚═════╝░╚═════╝░░░░╚═╝░░░╚══════╝╚══════╝  ╚═╝░░╚═╝╚═╝╚═╝░░╚═╝╚═════╝░╚═╝░░╚═╝░╚════╝░╚═╝░░░░░╚═════╝░  │"
    echo "└───────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘"
    echo -e "${YELLOW}                  🚀 Pipe Node Manager by Aashish 🚀${NC}"
    echo -e "${YELLOW}              GitHub: https://github.com/HustleAirdrops${NC}"
    echo -e "${YELLOW}              Telegram: https://t.me/Hustle_Airdrops${NC}"
    echo -e "${GREEN}===============================================================================${NC}"
}

handle_ctrl_c() {
    ((CTRL_C_COUNT++))
    if [ $IN_MENU -eq 1 ]; then
        echo -e "\n${RED}🚨 Exiting...${NC}"
        exit 0
    fi
    if [ $CTRL_C_COUNT -ge 2 ]; then
        echo -e "\n${RED}🚨 Multiple Ctrl+C detected. Exiting...${NC}"
        exit 0
    fi
    echo -e "\n${RED}🚨 Ctrl+C detected. Returning to menu...${NC}"
    sleep 1
    return_to_menu
}

return_to_menu() {
    CTRL_C_COUNT=0
    echo -e "\n${YELLOW}🔁 Press Enter to return to menu...${NC}"
    read
}

setup_venv() {
    VENV_DIR="$HOME/pipe_venv"
    echo -e "${BLUE}🛠️ Setting up Python virtual environment at $VENV_DIR...${NC}"
    if [ ! -d "$VENV_DIR" ]; then
        python3 -m venv "$VENV_DIR"
        if [ $? -ne 0 ]; then
            echo -e "${RED}❌ Failed to create virtual environment!${NC}"
            return 1
        fi
    fi
    source "$VENV_DIR/bin/activate"
    pip install --upgrade pip
    pip install yt-dlp requests
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Failed to install packages in venv!${NC}"
        deactivate
        return 1
    fi
    echo -e "${GREEN}✅ Packages installed successfully in venv!${NC}"
    deactivate
}

setup_pipe_path() {
    # Automatically sets up pipe path if needed, no errors or process end
    if [ -f "$HOME/.cargo/bin/pipe" ]; then
        if ! grep -q "export PATH=\$HOME/.cargo/bin:\$PATH" ~/.bashrc; then
            echo 'export PATH=$HOME/.cargo/bin:$PATH' >> ~/.bashrc
            echo -e "${GREEN}✅ Added pipe path to ~/.bashrc.${NC}"
        fi
        export PATH=$HOME/.cargo/bin:$PATH
        echo -e "${GREEN}✅ Updated PATH with pipe location.${NC}"
        if [ -f "$HOME/.cargo/env" ]; then
            source $HOME/.cargo/env
            echo -e "${GREEN}✅ Reloaded cargo environment.${NC}"
        fi
        chmod +x $HOME/.cargo/bin/pipe
        echo -e "${GREEN}✅ Ensured pipe is executable.${NC}"
    else
        echo -e "${YELLOW}⚠️ Pipe binary not found. Installation may be incomplete.${NC}"
    fi
}

install_node() {
    echo -e "${BLUE}🔍 Checking if Pipe is already installed...${NC}"
    if command -v pipe >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Pipe is already installed! Skipping installation.${NC}"
    else
        echo -e "${BLUE}🔄 Updating system and installing dependencies...${NC}"
        sudo apt update && sudo apt upgrade -y
        sudo apt install -y curl iptables build-essential git wget lz4 jq make gcc postgresql-client nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev tar clang bsdmainutils ncdu unzip libleveldb-dev libclang-dev ninja-build python3 python3-venv ffmpeg

        setup_venv
        if [ $? -ne 0 ]; then
            echo -e "${RED}❌ Python environment setup failed. You can still use other menu options, but file upload may not work.${NC}"
        fi

        echo -e "${BLUE}🦀 Installing Rust...${NC}"
        curl https://sh.rustup.rs -sSf | sh -s -- -y
        source $HOME/.cargo/env

        echo -e "${BLUE}📥 Cloning and installing Pipe...${NC}"
        git clone https://github.com/PipeNetwork/pipe.git $HOME/pipe
        cd $HOME/pipe
        cargo install --path .
        cd $HOME

        # Automatically setup pipe path if not working
        if ! command -v pipe >/dev/null 2>&1; then
            setup_pipe_path
        fi

        echo -e "${BLUE}🔍 Verifying Pipe installation...${NC}"
        if ! pipe -h >/dev/null 2>&1; then
            echo -e "${RED}❌ Pipe installation failed! Checking PATH: $PATH${NC}"
            return_to_menu
            return
        fi

        echo -e "${GREEN}✅ Pipe installed successfully!${NC}"
    fi

    read -r -p "$(echo -e ${YELLOW}👤 Enter your desired username: ${NC})" username
    echo -e "${BLUE}🆕 Creating new user...${NC}"
    pipe_output=$(pipe new-user "$username" 2>&1)
    echo -e "${GREEN}✅ User created. Save these details:${NC}"
    echo "$pipe_output"

    solana_pubkey=$(echo "$pipe_output" | grep "Solana Pubkey" | awk '{print $NF}')
    echo -e "${GREEN}🔑 Your Solana Public Key: $solana_pubkey${NC}"

    if [ -n "$solana_pubkey" ] && [ -f "$HOME/.pipe-cli.json" ]; then
        jq --arg sp "$solana_pubkey" '. + {solana_pubkey: $sp}' "$HOME/.pipe-cli.json" > tmp.json && mv tmp.json "$HOME/.pipe-cli.json"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ Solana Public Key saved to ~/.pipe-cli.json${NC}"
        else
            echo -e "${RED}❌ Failed to save Solana Public Key to ~/.pipe-cli.json${NC}"
        fi
    else
        echo -e "${RED}❌ Could not save Solana Public Key: File or key not found.${NC}"
    fi

    echo -e "${BLUE}💾 Your credentials are below. Copy and save them, then press Enter to continue:${NC}"
    cat "/home/$USER/.pipe-cli.json"
    read -s -p "Press Enter after saving your credentials..."

    clear

    read -p "$(echo -e ${YELLOW}🔗 Enter a referral code \(or press Enter to use default\): ${NC})" referral_code

    if [ -z "$referral_code" ]; then
        referral_code="ITZMEAAS-PFJU"
        echo -e "${YELLOW}🔗 Using default referral code: $referral_code${NC}"
    fi

    echo -e "${BLUE}✅ Applying referral code...${NC}"
    pipe referral apply "$referral_code"
    pipe referral generate >/dev/null 2>&1

    echo -e "${YELLOW}💰 Claim 5 Devnet SOL from https://faucet.solana.com/ using your Solana Public Key: $solana_pubkey${NC}"
    read -r -p "$(echo -e ${YELLOW}✅ Enter 'yes' to confirm you have claimed the SOL: ${NC})" confirmation

    if [ "$confirmation" = "yes" ]; then
        echo -e "${BLUE}⏳ Waiting 10 seconds before swapping...${NC}"
        sleep 10
        echo -e "${BLUE}🔄 Swapping 2 SOL for PIPE...${NC}"
        swap_output=$(pipe swap-sol-for-pipe 2 2>&1)
        echo "$swap_output"
    else
        echo -e "${RED}❌ SOL not claimed. Returning to menu.${NC}"
        return_to_menu
        return
    fi
    return_to_menu
}

upload_file() {
    VENV_DIR="$HOME/pipe_venv"
    if [ ! -d "$VENV_DIR" ]; then
        echo -e "${RED}❌ Virtual environment not found. Setting it up now...${NC}"
        setup_venv
        if [ $? -ne 0 ]; then
            echo -e "${RED}❌ Failed to set up virtual environment. Returning to menu.${NC}"
            return_to_menu
            return
        fi
    fi
    source "$VENV_DIR/bin/activate"
    if ! pip show yt-dlp >/dev/null 2>&1 || ! pip show requests >/dev/null 2>&1; then
        echo -e "${YELLOW}🛠️ Installing missing packages...${NC}"
        pip install --upgrade pip
        pip install yt-dlp requests
        if [ $? -ne 0 ]; then
            echo -e "${RED}❌ Failed to install packages. Please check your internet connection or pip configuration.${NC}"
            deactivate
            return_to_menu
            return
        fi
        echo -e "${GREEN}✅ Packages installed successfully!${NC}"
    fi

    while true; do
        clear
        show_header
        echo -e "${BLUE}${BOLD}======================= Upload File Submenu =======================${NC}"
        echo -e "${YELLOW}1. 📹 Upload from YouTube (yt-dlp)${NC}"
        echo -e "${YELLOW}2. 🎥 Upload from Pixabay${NC}"
        echo -e "${YELLOW}3. 🗂️ Manual Upload (from home or pipe folder)${NC}"
        echo -e "${YELLOW}4. 🔙 Back to Main Menu${NC}"
        echo -e "${BLUE}=================================================================${NC}"
        read -p "$(echo -e ${YELLOW}Select an option: ${NC})" subchoice
        case $subchoice in
            1)
                read -p "$(echo -e ${YELLOW}🔍 Enter a search query for the video \(e.g., 'random full hd'\): ${NC})" query
                echo -e "${BLUE}📥 Downloading video from YouTube...${NC}"
                random_suffix=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
                output_file="video_$random_suffix.mp4"
                python3 video_downloader.py "$query" "$output_file"
                ;;
            2)
                API_KEY_FILE="$HOME/.pixabay_api_key"
                if [ ! -f "$API_KEY_FILE" ]; then
                    read -p "$(echo -e ${YELLOW}🔑 Enter your Pixabay API key: ${NC})" api_key
                    echo "$api_key" > "$API_KEY_FILE"
                    echo -e "${GREEN}✅ API key saved for future use.${NC}"
                fi
                read -p "$(echo -e ${YELLOW}🔍 Enter a search query for the video \(e.g., 'nature'\): ${NC})" query
                echo -e "${BLUE}📥 Downloading video from Pixabay...${NC}"
                random_suffix=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
                output_file="video_$random_suffix.mp4"
                python3 pixabay_downloader.py "$query" "$output_file"
                ;;
            3)
                echo -e "${BLUE}🔍 Searching for .mp4 files in $HOME and $HOME/pipe...${NC}"
                videos=($(find "$HOME" "$HOME/pipe" -type f -name "*.mp4" 2>/dev/null))
                if [ ${#videos[@]} -eq 0 ]; then
                    echo -e "${RED}❌ No .mp4 files found.${NC}"
                    return_to_menu
                    continue
                fi
                echo -e "${YELLOW}Available videos:${NC}"
                for i in "${!videos[@]}"; do
                    size=$(du -h "${videos[i]}" | cut -f1)
                    echo "$((i+1)). ${videos[i]} ($size)"
                done
                read -p "$(echo -e ${YELLOW}Select a number: ${NC})" num
                if [[ $num =~ ^[0-9]+$ ]] && [ $num -ge 1 ] && [ $num -le ${#videos[@]} ]; then
                    selected="${videos[$((num-1))]}"
                    output_file="${selected##*/}"
                    echo -e "${GREEN}✅ Selected: $selected${NC}"
                else
                    echo -e "${RED}❌ Invalid selection.${NC}"
                    return_to_menu
                    continue
                fi
                ;;
            4) deactivate; return ;;
            *) echo -e "${RED}❌ Invalid option. Try again.${NC}"; sleep 1; continue ;;
        esac

        deactivate

        if [ -f "$output_file" ] || [ "$subchoice" = "3" ]; then
            if [ "$subchoice" = "3" ]; then
                file_to_upload="$selected"
            else
                file_to_upload="$output_file"
            fi
            echo -e "${BLUE}⬆️ Uploading video...${NC}"
            # Automatically setup path if pipe command fails
            if ! command -v pipe >/dev/null 2>&1; then
                setup_pipe_path
            fi
            upload_output=$(pipe upload-file "$file_to_upload" "$output_file" 2>&1)
            echo "$upload_output"
            file_id=$(echo "$upload_output" | grep "File ID (Blake3)" | awk '{print $NF}')
            link_output=$(pipe create-public-link "$output_file")
            echo "$link_output"
            direct_link=$(echo "$link_output" | grep "Direct link" -A 1 | tail -n 1 | awk '{$1=$1};1')
            social_link=$(echo "$link_output" | grep "Social media link" -A 1 | tail -n 1 | awk '{$1=$1};1')
            if [ -n "$file_id" ]; then
                echo -e "${BLUE}💾 Saving file details to file_details.json...${NC}"
                if [ ! -f "file_details.json" ]; then
                    echo "[]" > file_details.json
                fi
                jq --arg fn "$output_file" --arg fid "$file_id" --arg dl "$direct_link" --arg sl "$social_link" \
                    '. + [{"file_name": $fn, "file_id": $fid, "direct_link": $dl, "social_link": $sl}]' \
                    file_details.json > tmp.json && mv tmp.json file_details.json
                if [ "$subchoice" != "3" ]; then
                    echo -e "${BLUE}🗑️ Deleting local video file...${NC}"
                    rm -f "$output_file"
                fi
            else
                echo -e "${RED}❌ Failed to extract File ID.${NC}"
            fi
        else
            echo -e "${RED}❌ No video file found.${NC}"
        fi
        return_to_menu
    done
}

show_file_info() {
    echo -e "${BLUE}📄 Uploaded File Details:${NC}"
    if [ -f "file_details.json" ]; then
        count=$(jq '. | length' file_details.json)
        if [ "$count" -eq 0 ]; then
            echo -e "${RED}❌ No file details found in file_details.json.${NC}"
        else
            for ((i=0; i<count; i++)); do
                echo -e "${BLUE}📂 File $((i+1)) of $count:${NC}"
                file_name=$(jq -r ".[$i].file_name" file_details.json)
                file_id=$(jq -r ".[$i].file_id" file_details.json)
                direct_link=$(jq -r ".[$i].direct_link" file_details.json)
                social_link=$(jq -r ".[$i].social_link" file_details.json)
                echo -e "${YELLOW}📋 File Name: ${GREEN}$file_name${NC}"
                echo -e "${YELLOW}🆔 File ID: ${GREEN}$file_id${NC}"
                echo -e "${YELLOW}🔗 Direct Download Link: ${GREEN}$direct_link${NC}"
                echo -e "${YELLOW}🌐 Social Media Share Link: ${GREEN}$social_link${NC}"
                echo -e "${BLUE}--------------------------------${NC}"
            done
        fi
    else
        echo -e "${RED}❌ No file details found.${NC}"
    fi
    return_to_menu
}

show_credentials() {
    echo -e "${BLUE}🔑 Pipe Credentials:${NC}"
    if [ -f "$HOME/.pipe-cli.json" ]; then
        user_id=$(jq -r '.user_id' "$HOME/.pipe-cli.json")
        user_app_key=$(jq -r '.user_app_key' "$HOME/.pipe-cli.json")
        username=$(jq -r '.username' "$HOME/.pipe-cli.json")
        access_token=$(jq -r '.auth_tokens.access_token' "$HOME/.pipe-cli.json")
        refresh_token=$(jq -r '.auth_tokens.refresh_token' "$HOME/.pipe-cli.json")
        token_type=$(jq -r '.auth_tokens.token_type' "$HOME/.pipe-cli.json")
        expires_in=$(jq -r '.auth_tokens.expires_in' "$HOME/.pipe-cli.json")
        expires_at=$(jq -r '.auth_tokens.expires_at' "$HOME/.pipe-cli.json")
        solana_pubkey=$(jq -r '.solana_pubkey // "Not found"' "$HOME/.pipe-cli.json")
        
        read -p "$(echo -e ${YELLOW}🔍 Show full Access and Refresh Tokens? \(y/n, default n\): ${NC})" show_full
        echo -e "${YELLOW}👤 Username: ${GREEN}$username${NC}"
        echo -e "${YELLOW}🆔 User ID: ${GREEN}$user_id${NC}"
        echo -e "${YELLOW}🔐 User App Key: ${GREEN}$user_app_key${NC}"
        echo -e "${YELLOW}🔑 Solana Public Key: ${GREEN}$solana_pubkey${NC}"
        echo -e "${YELLOW}🔒 Auth Tokens:${NC}"
        echo -e "${YELLOW}📜 Token Type: ${GREEN}$token_type${NC}"
        echo -e "${YELLOW}⏳ Expires In: ${GREEN}$expires_in seconds${NC}"
        echo -e "${YELLOW}📅 Expires At: ${GREEN}$expires_at${NC}"
        if [ "$show_full" = "y" ] || [ "$show_full" = "Y" ]; then
            echo -e "${YELLOW}🔑 Access Token: ${GREEN}$access_token${NC}"
            echo -e "${YELLOW}🔄 Refresh Token: ${GREEN}$refresh_token${NC}"
        else
            echo -e "${YELLOW}🔑 Access Token: ${GREEN}${access_token:0:20}... (truncated for brevity)${NC}"
            echo -e "${YELLOW}🔄 Refresh Token: ${GREEN}${refresh_token:0:20}... (truncated for brevity)${NC}"
        fi
    else
        echo -e "${RED}❌ Credentials file (~/.pipe-cli.json) not found.${NC}"
    fi
    return_to_menu
}

show_referral() {
    echo -e "${BLUE}📊 Your referral stats:${NC}"
    pipe referral show
    return_to_menu
}

swap_tokens() {
    echo "-----------------------------------"
    echo "🔥 PIPE Swapping Menu 🔥"
    echo "-----------------------------------"
    read -p "Enter amount to swap: " AMOUNT

    if [[ -z "$AMOUNT" ]]; then
        echo "❌ Amount cannot be empty!"
        return
    fi

    echo "✅ Swapping $AMOUNT PIPE tokens..."
    pipe swap-sol-for-pipe "$AMOUNT"

    if [[ $? -eq 0 ]]; then
        echo "🎉 Successfully swap $AMOUNT PIPE!"
    else
        echo "⚠️ Error while swapping tokens."
    fi
    return_to_menu
}

check_token_usage() {
    echo -e "${BLUE}📈 Checking token usage...${NC}"
    pipe token-usage
    return_to_menu
}

cat << 'EOF' > video_downloader.py
import yt_dlp
import os
import sys
import time
import random
import string
import subprocess

def format_size(bytes_size):
    return f"{bytes_size/(1024*1024):.2f} MB"

def format_time(seconds):
    mins = int(seconds // 60)
    secs = int(seconds % 60)
    return f"{mins:02d}:{secs:02d}"

def draw_progress_bar(progress, total, width=50):
    percent = progress / total * 100
    filled = int(width * progress // total)
    bar = '█' * filled + '-' * (width - filled)
    return f"[{bar}] {percent:.1f}%"

def download_videos(query, output_file, target_size_mb=1000, max_filesize=1100*1024*1024, min_filesize=50*1024*1024):
    ydl_opts = {
        'format': 'best',
        'noplaylist': True,
        'quiet': True,
        'progress_hooks': [progress_hook],
        'outtmpl': '%(title)s.%(ext)s'
    }
    
    total_downloaded = 0
    total_size = 0
    start_time = time.time()
    downloaded_files = []
    
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        info = ydl.extract_info(f"ytsearch20:{query}", download=False)
        videos = info.get("entries", [])
        candidates = []
        for v in videos:
            size = v.get("filesize") or v.get("filesize_approx")
            if size and min_filesize <= size <= max_filesize:
                candidates.append((size, v))
        
        if not candidates:
            print("\033[0;31m❌ No suitable videos found (at least 50MB and up to ~1GB).\033[0m")
            return
        
        for size, v in sorted(candidates, key=lambda x: -x[0]):
            if total_size + size <= target_size_mb * 1024 * 1024:
                total_size += size
                current_file = len(downloaded_files) + 1
                print(f"\033[0;34m🎬 Downloading video {current_file}: {v['title']} ({format_size(size)})\033[0m")
                ydl.download([v['webpage_url']])
                filename = ydl.prepare_filename(v)
                downloaded_files.append(filename)
                total_downloaded += size
                
                elapsed = time.time() - start_time
                speed = total_downloaded / (1024*1024*elapsed) if elapsed > 0 else 0
                eta = (total_size - total_downloaded) / (speed * 1024*1024) if speed > 0 else 0
                
                print(f"\033[0;32m✅ Overall Progress: {draw_progress_bar(total_downloaded, total_size)} "
                      f"({format_size(total_downloaded)}/{format_size(total_size)}) "
                      f"Speed: {speed:.2f} MB/s ETA: {format_time(eta)}\033[0m")

    if not downloaded_files:
        print("\033[0;31m❌ No videos found close to 1GB.\033[0m")
        return

    if len(downloaded_files) == 1:
        os.rename(downloaded_files[0], output_file)
    else:
        with open('list.txt', 'w') as f:
            for fn in downloaded_files:
                f.write(f"file '{fn}'\n")
        subprocess.call(['ffmpeg', '-f', 'concat', '-safe', '0', '-i', 'list.txt', '-c', 'copy', output_file])
        os.remove('list.txt')
        for fn in downloaded_files:
            os.remove(fn)

    print(f"\033[0;32m✅ Video ready: {output_file} ({format_size(os.path.getsize(output_file))})\033[0m")

def progress_hook(d):
    if d['status'] == 'downloading':
        downloaded = d.get('downloaded_bytes', 0)
        total = d.get('total_bytes', d.get('total_bytes_estimate', 1000000))
        speed = d.get('speed', 0) or 0
        eta = d.get('eta', 0) or 0
        print(f"\r\033[0;34m⬇️ File Progress: {draw_progress_bar(downloaded, total)} "
              f"({format_size(downloaded)}/{format_size(total)}) "
              f"Speed: {speed/(1024*1024):.2f} MB/s ETA: {format_time(eta)}\033[0m", end='')
    elif d['status'] == 'finished':
        print("\r\033[0;32m✅ File Download completed\033[0m")

if __name__ == "__main__":
    if len(sys.argv) > 2:
        download_videos(sys.argv[1], sys.argv[2])
    else:
        print("\033[0;31mPlease provide a search query and output filename.\033[0m")
EOF

cat << 'EOF' > pixabay_downloader.py
import requests
import os
import sys
import time
import random
import string
import subprocess

def format_size(bytes_size):
    return f"{bytes_size/(1024*1024):.2f} MB"

def format_time(seconds):
    mins = int(seconds // 60)
    secs = int(seconds % 60)
    return f"{mins:02d}:{secs:02d}"

def draw_progress_bar(progress, total, width=50):
    percent = progress / total * 100
    filled = int(width * progress // total)
    bar = '█' * filled + '-' * (width - filled)
    return f"[{bar}] {percent:.1f}%"

def download_videos(query, output_file, target_size_mb=1000):
    api_key_file = os.path.expanduser('~/.pixabay_api_key')
    if not os.path.exists(api_key_file):
        print("\033[0;31m❌ Pixabay API key file not found.\033[0m")
        return
    with open(api_key_file, 'r') as f:
        api_key = f.read().strip()

    per_page = 100
    url = f"https://pixabay.com/api/videos/?key={api_key}&q={query}&per_page={per_page}&min_width=1920&min_height=1080&video_type=all"
    resp = requests.get(url)
    if resp.status_code != 200:
        print("\033[0;31m❌ Error fetching Pixabay API: {resp.text}\033[0m")
        return
    data = resp.json()
    videos = data.get('hits', [])
    if not videos:
        print("\033[0;31m❌ No videos found for query.\033[0m")
        return

    videos.sort(key=lambda x: x['duration'], reverse=True)

    downloaded_files = []
    total_size = 0
    total_downloaded = 0
    start_time = time.time()

    for i, v in enumerate(videos):
        video_url = v['videos'].get('large', {}).get('url') or v['videos'].get('medium', {}).get('url')
        if not video_url:
            continue
        filename = f"pix_{i}_{''.join(random.choices(string.ascii_letters + string.digits, k=8))}.mp4"
        print(f"\033[0;34m🎬 Downloading video {i+1}: {v['tags']} ({v['duration']}s)\033[0m")
        resp = requests.get(video_url, stream=True)
        size = int(resp.headers.get('content-length', 0))
        if size < 50 * 1024 * 1024:  # Skip if <50MB
            continue
        with open(filename, 'wb') as f:
            downloaded = 0
            for chunk in resp.iter_content(chunk_size=8192):
                if chunk:
                    f.write(chunk)
                    downloaded += len(chunk)
                    percent = downloaded / size * 100 if size else 0
                    speed = downloaded / (1024*1024 * (time.time() - start_time)) if (time.time() - start_time) > 0 else 0
                    eta = (size - downloaded) / (speed * 1024*1024) if speed > 0 else 0
                    print(f"\r\033[0;34m⬇️ File Progress: {draw_progress_bar(downloaded, size)} "
                          f"({format_size(downloaded)}/{format_size(size)}) "
                          f"Speed: {speed:.2f} MB/s ETA: {format_time(eta)}\033[0m", end='')
        print("\r\033[0;32m✅ File Download completed\033[0m")
        file_size = os.path.getsize(filename)
        if file_size == 0:
            os.remove(filename)
            continue
        total_size += file_size
        total_downloaded += file_size
        downloaded_files.append(filename)
        if total_size >= target_size_mb * 1024 * 1024:
            break

    if not downloaded_files:
        print("\033[0;31m❌ No suitable videos downloaded.\033[0m")
        return

    if len(downloaded_files) == 1:
        os.rename(downloaded_files[0], output_file)
    else:
        with open('list.txt', 'w') as f:
            for fn in downloaded_files:
                f.write(f"file '{fn}'\n")
        subprocess.call(['ffmpeg', '-f', 'concat', '-safe', '0', '-i', 'list.txt', '-c', 'copy', output_file])
        os.remove('list.txt')
        for fn in downloaded_files:
            os.remove(fn)

    print(f"\033[0;32m✅ Video ready: {output_file} ({format_size(os.path.getsize(output_file))})\033[0m")

if __name__ == "__main__":
    if len(sys.argv) > 2:
        download_videos(sys.argv[1], sys.argv[2])
    else:
        print("\033[0;31mPlease provide a search query and output filename.\033[0m")
EOF

while true; do
    show_header
    echo -e "${BLUE}${BOLD}======================= Pipe NODE MANAGER BY Aashish 💖 =======================${NC}"
    echo -e "${YELLOW}1. 🛠️ Install Node${NC}"
    echo -e "${YELLOW}2. ⬆️ Upload File${NC}"
    echo -e "${YELLOW}3. 📄 Show Uploaded File Info${NC}"
    echo -e "${YELLOW}4. 🔗 Show Referral Stats and Code${NC}"
    echo -e "${YELLOW}5. 📈 Check Token Usage${NC}"
    echo -e "${YELLOW}6. 🔑 Show Credentials${NC}"
    echo -e "${YELLOW}7. 🔥 Swap tokens${NC}"
    echo -e "${YELLOW}8. ❌ Exit${NC}"
    echo -e "${BLUE}=============================================================================${NC}"
    IN_MENU=1
    read -p "$(echo -e ${YELLOW}Select an option: ${NC})" choice
    IN_MENU=0
    case $choice in
        1) install_node ;;
        2) upload_file ;;
        3) show_file_info ;;
        4) show_referral ;;
        5) check_token_usage ;;
        6) show_credentials ;;
        7) swap_tokens ;;
        8) echo -e "${GREEN}👋 Exiting...${NC}"; exit 0 ;;
        *) echo -e "${RED}❌ Invalid option. Try again.${NC}"; sleep 1 ;;
    esac
done
