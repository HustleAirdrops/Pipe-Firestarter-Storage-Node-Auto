#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
BOLD='\033[1m'
CTRL_C_COUNT=0

trap 'handle_ctrl_c' SIGINT

show_header() {
    clear
    echo -e "${BLUE}${BOLD}"
    echo -e "${GREEN}===============================================================================${NC}"
    echo -e "${YELLOW}                  🚀 Pipe Node Manager by Aashish 🚀${NC}"
    echo -e "${YELLOW}              GitHub: https://github.com/HustleAirdrops${NC}"
    echo -e "${YELLOW}              Telegram: https://t.me/Hustle_Airdrops${NC}"
    echo -e "${GREEN}===============================================================================${NC}"
}

handle_ctrl_c() {
    ((CTRL_C_COUNT++))
    if [ $CTRL_C_COUNT -ge 2 ]; then
        echo -e "\n${RED}🚨 Multiple Ctrl+C detected. Exiting...${NC}"
        exit 0
    fi
    echo -e "\n${RED}🚨 Ctrl+C detected. Exiting...${NC}"
    exit 0
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
    pip install yt-dlp
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Failed to install yt-dlp in venv!${NC}"
        deactivate
        return 1
    fi
    echo -e "${GREEN}✅ yt-dlp installed successfully in venv!${NC}"
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
        sudo apt install -y curl iptables build-essential git wget lz4 jq make gcc postgresql-client nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev tar clang bsdmainutils ncdu unzip libleveldb-dev libclang-dev ninja-build python3 python3-venv

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
        echo -e "${RED}❌ SOL not claimed. Exiting.${NC}"
        exit 1
    fi
}

upload_file() {
    local query="$1"
    local output_file="$2"
    VENV_DIR="$HOME/pipe_venv"
    if [ ! -d "$VENV_DIR" ]; then
        echo -e "${RED}❌ Virtual environment not found. Setting it up now...${NC}"
        setup_venv
        if [ $? -ne 0 ]; then
            echo -e "${RED}❌ Failed to set up virtual environment.${NC}"
            return
        fi
    fi
    source "$VENV_DIR/bin/activate"
    if ! pip show yt-dlp >/dev/null 2>&1; then
        echo -e "${YELLOW}🛠️ yt-dlp not found. Installing yt-dlp...${NC}"
        pip install --upgrade pip
        pip install yt-dlp
        if [ $? -ne 0 ]; then
            echo -e "${RED}❌ Failed to install yt-dlp. Please check your internet connection or pip configuration.${NC}"
            deactivate
            return
        fi
        echo -e "${GREEN}✅ yt-dlp installed successfully!${NC}"
    fi
    echo -e "${BLUE}📥 Downloading video...${NC}"
    python3 video_downloader.py "$query" "$output_file"
    deactivate
    if [ -f "$output_file" ]; then
        echo -e "${BLUE}⬆️ Uploading video...${NC}"
        # Automatically setup path if pipe command fails
        if ! command -v pipe >/dev/null 2>&1; then
            setup_pipe_path
        fi
        upload_output=$(pipe upload-file "./$output_file" "$output_file" 2>&1)
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
            echo -e "${BLUE}🗑️ Deleting local video file...${NC}"
            rm -f "$output_file"
        else
            echo -e "${RED}❌ Failed to extract File ID.${NC}"
        fi
    else
        echo -e "${RED}❌ No video file found.${NC}"
    fi
}

check_token_usage() {
    echo -e "${BLUE}📈 Checking token usage...${NC}"
    pipe token-usage
}

cat << 'EOF' > video_downloader.py
import yt_dlp
import os
import sys
import time
import random
import string

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
    filenames = []
    
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
                filenames.append((size, v))
        
        if not filenames:
            print("\033[0;31m❌ No videos found close to 1GB.\033[0m")
            return

        total_files = len(filenames)
        current_file = 0
        
        for size, video in filenames:
            current_file += 1
            print(f"\033[0;34m🎬 Downloading video {current_file}/{total_files}: {video['title']} ({format_size(size)})\033[0m")
            ydl.download([video['webpage_url']])
            filename = ydl.prepare_filename(video)
            total_downloaded += size
            with open(filename, "rb") as infile:
                with open(output_file, "ab") as outfile:
                    outfile.write(infile.read())
            os.remove(filename)
            
            elapsed = time.time() - start_time
            speed = total_downloaded / (1024*1024*elapsed) if elapsed > 0 else 0
            eta = (total_size - total_downloaded) / (speed * 1024*1024) if speed > 0 else 0
            
            print(f"\033[0;32m✅ Overall Progress: {draw_progress_bar(total_downloaded, total_size)} "
                  f"({format_size(total_downloaded)}/{format_size(total_size)}) "
                  f"Speed: {speed:.2f} MB/s ETA: {format_time(eta)}\033[0m")

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

show_header
install_node
echo -e "${YELLOW}🔍 Enter a search query for the videos (e.g., 'random full hd'):${NC}"
read query
echo -e "${YELLOW}📁 Enter base file name (without extension, e.g., 'myvideo'):${NC}"
read base_name
echo -e "${YELLOW}💾 Enter how many GB to upload (integer, each ~1GB file):${NC}"
read num_gb
for ((i=1; i<=num_gb; i++)); do
    upload_file "$query" "${base_name}_${i}.mp4"
    sleep $((10 + RANDOM % 6))
done
echo -e "${YELLOW}📄 Enter name for combined links file (e.g., 'all_links.txt'):${NC}"
read combined_name
combined_file="$combined_name"
> "$combined_file"
echo "Uploaded Files Details:" >> "$combined_file"
if [ -f "file_details.json" ]; then
    count=$(jq '. | length' file_details.json)
    for ((j=0; j<count; j++)); do
        file_name=$(jq -r ".[$j].file_name" file_details.json)
        file_id=$(jq -r ".[$j].file_id" file_details.json)
        direct_link=$(jq -r ".[$j].direct_link" file_details.json)
        social_link=$(jq -r ".[$j].social_link" file_details.json)
        echo "File: $file_name" >> "$combined_file"
        echo "ID: $file_id" >> "$combined_file"
        echo "Direct Link: $direct_link" >> "$combined_file"
        echo "Social Link: $social_link" >> "$combined_file"
        echo "-------------------" >> "$combined_file"
    done
else
    echo "No files uploaded." >> "$combined_file"
fi
echo -e "${BLUE}⬆️ Uploading combined links file...${NC}"
# Automatically setup path if pipe command fails
if ! command -v pipe >/dev/null 2>&1; then
    setup_pipe_path
fi
upload_output=$(pipe upload-file "./$combined_file" "$combined_file" 2>&1)
echo "$upload_output"
file_id=$(echo "$upload_output" | grep "File ID (Blake3)" | awk '{print $NF}')
link_output=$(pipe create-public-link "$combined_file")
echo "$link_output"
direct_link=$(echo "$link_output" | grep "Direct link" -A 1 | tail -n 1 | awk '{$1=$1};1')
social_link=$(echo "$link_output" | grep "Social media link" -A 1 | tail -n 1 | awk '{$1=$1};1')
echo -e "${YELLOW}Combined Links File:${NC}"
echo -e "${YELLOW}🆔 File ID: ${GREEN}$file_id${NC}"
echo -e "${YELLOW}🔗 Direct Link: ${GREEN}$direct_link${NC}"
echo -e "${YELLOW}🌐 Social Link: ${GREEN}$social_link${NC}"
rm "$combined_file"
check_token_usage
echo -e "${GREEN}👋 Process completed.${NC}"
