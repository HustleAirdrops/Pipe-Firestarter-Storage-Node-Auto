#!/bin/bash

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counter for Ctrl+C presses AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
CTRL_C_COUNT=0

# Trap Ctrl+C to allow graceful exit after one press
trap 'handle_ctrl_c' SIGINT

# Function to handle Ctrl+C
handle_ctrl_c() {
    ((CTRL_C_COUNT++))
    if [ $CTRL_C_COUNT -ge 2 ]; then
        echo -e "${RED}Multiple Ctrl+C detected. Exiting...${NC}"
        exit 0
    fi
    echo -e "${RED}Ctrl+C detected. Returning to menu...${NC}"
    sleep 1
    return_to_menu
}

# Function to return to menu
return_to_menu() {
    CTRL_C_COUNT=0 # Reset Ctrl+C counter
    echo -e "${BLUE}Returning to main menu...${NC}"
    sleep 1
}

# Function to set up Python environment
setup_python_env() {
    echo -e "${BLUE}Installing pipx and setting up Python environment...${NC}"
    sudo apt install -y pipx
    pipx ensurepath
    source ~/.bashrc
    pipx install yt-dlp
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}yt-dlp installed successfully via pipx!${NC}"
    else
        echo -e "${YELLOW}pipx failed. Trying fallback with venv...${NC}"
        VENV_DIR="$HOME/pipe_venv"
        if [ ! -d "$VENV_DIR" ]; then
            echo -e "${BLUE}Creating Python virtual environment at $VENV_DIR...${NC}"
            python3 -m venv "$VENV_DIR"
            if [ $? -ne 0 ]; then
                echo -e "${RED}Failed to create virtual environment!${NC}"
                return 1
            fi
            source "$VENV_DIR/bin/activate"
            pip install --upgrade pip
            pip install yt-dlp
            if [ $? -ne 0 ]; then
                echo -e "${RED}Failed to install yt-dlp in venv!${NC}"
                deactivate
                return 1
            fi
            deactivate
        else
            echo -e "${BLUE}Virtual environment already exists at $VENV_DIR.${NC}"
        fi
    fi
}

# Function to install dependencies and Pipe node
install_node() {
    echo -e "${BLUE}Updating system and installing dependencies...${NC}"
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y curl iptables build-essential git wget lz4 jq make gcc postgresql-client nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev tar clang bsdmainutils ncdu unzip libleveldb-dev libclang-dev ninja-build python3 python3-venv python3-pip pipx
    setup_python_env
    if [ $? -ne 0 ]; then
        echo -e "${RED}Python environment setup failed. Continuing without yt-dlp...${NC}"
    fi

    echo -e "${BLUE}Installing Rust...${NC}"
    curl https://sh.rustup.rs -sSf | sh -s -- -y
    source $HOME/.cargo/env

    echo -e "${BLUE}Cloning and installing Pipe...${NC}"
    git clone https://github.com/PipeNetwork/pipe.git
    cd pipe
    cargo install --path .
    cd ..

    echo -e "${BLUE}Verifying Pipe installation...${NC}"
    pipe -h
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Pipe installed successfully!${NC}"
    else
        echo -e "${RED}Pipe installation failed!${NC}"
        return_to_menu
        return
    fi

    echo -e "${YELLOW}Enter your desired username:${NC}"
    read username
    echo -e "${BLUE}Creating new user...${NC}"
    pipe_output=$(pipe new-user "$username" 2>&1)
    echo -e "${GREEN}User created. Save these details:${NC}"
    echo "$pipe_output"

    # Extract Solana public key
    solana_pubkey=$(echo "$pipe_output" | grep "Solana Pubkey" | awk '{print $NF}')
    echo -e "${GREEN}Your Solana Public Key: $solana_pubkey${NC}"

    # Save credentials
    echo -e "${BLUE}Saving credentials to /home/$USER/.pipe-cli.json...${NC}"
    nano /home/$USER/.pipe-cli.json

    # Handle referral code
    echo -e "${YELLOW}Enter a referral code (or press Enter to use default):${NC}"
    read referral_code
    if [ -z "$referral_code" ]; then
        referral_code="ITZMEAAS-PFJU"
        echo -e "${YELLOW}Using default referral code: $referral_code${NC}"
    fi
    echo -e "${BLUE}Applying referral code...${NC}"
    pipe referral apply "$referral_code"

    echo -e "${BLUE}Generating your referral code...${NC}"
    pipe referral generate
    echo -e "${BLUE}Your referral stats:${NC}"
    pipe referral show

    echo -e "${YELLOW}Claim 5 Devnet SOL from https://faucet.solana.com/ using your Solana Public Key: $solana_pubkey${NC}"
    echo -e "${YELLOW}Enter 'yes' to confirm you have claimed the SOL:${NC}"
    read confirmation
    if [ "$confirmation" = "yes" ]; then
        echo -e "${BLUE}Swapping 2 SOL for PIPE...${NC}"
        pipe swap-sol-for-pipe 2
    else
        echo -e "${RED}SOL not claimed. Returning to menu.${NC}"
        return_to_menu
        return
    fi
}

# Function to download and upload video
upload_file() {
    echo -e "${YELLOW}Enter a search query for the video (e.g., 'random full hd'):${NC}"
    read query
    echo -e "${BLUE}Downloading video...${NC}"
    if command -v yt-dlp >/dev/null 2>&1; then
        python3 video_downloader.py "$query"
    else
        VENV_DIR="$HOME/pipe_venv"
        if [ -d "$VENV_DIR" ]; then
            source "$VENV_DIR/bin/activate"
            if pip show yt-dlp >/dev/null 2>&1; then
                python3 video_downloader.py "$query"
            else
                echo -e "${RED}yt-dlp not found in venv. Please run option 1 to set up the environment.${NC}"
                deactivate
                return_to_menu
                return
            fi
            deactivate
        else
            echo -e "${RED}Virtual environment not found. Please run option 1 to set up the environment.${NC}"
            return_to_menu
            return
        fi
    fi

    if [ -f "combined_video.mp4" ]; then
        echo -e "${BLUE}Uploading video...${NC}"
        upload_output=$(pipe upload-file ./combined_video.mp4 combined_video.mp4 2>&1)
        echo "$upload_output"

        # Extract File ID
        file_id=$(echo "$upload_output" | grep "File ID (Blake3)" | awk '{print $NF}')
        if [ -n "$file_id" ]; then
            echo -e "${BLUE}Saving file details to file_details.json...${NC}"
            cat << EOF > file_details.json
{
  "file_name": "combined_video.mp4",
  "file_id": "$file_id"
}
EOF
            echo -e "${BLUE}Creating public link for the uploaded file...${NC}"
            link_output=$(pipe create-public-link combined_video.mp4)
            echo "$link_output"

            echo -e "${BLUE}Deleting local video file...${NC}"
            rm -f combined_video.mp4
        else
            echo -e "${RED}Failed to extract File ID.${NC}"
        fi
    else
        echo -e "${RED}No video file found.${NC}"
    fi
    return_to_menu
}

# Function to show uploaded file info
show_file_info() {
    if [ -f "file_details.json" ]; then
        echo -e "${BLUE}Uploaded file details:${NC}"
        cat file_details.json
    else
        echo -e "${RED}No file details found.${NC}"
    fi
    return_to_menu
}

# Function to show referral stats and code
show_referral() {
    echo -e "${BLUE}Your referral stats:${NC}"
    pipe referral show
    echo -e "${BLUE}Your referral code:${NC}"
    pipe referral generate
    return_to_menu
}

# Function to check token usage
check_token_usage() {
    echo -e "${BLUE}Checking token usage...${NC}"
    pipe token-usage
    return_to_menu
}

# Python script for video downloading
cat << 'EOF' > video_downloader.py
import yt_dlp
import os

def download_videos(query, target_size_mb=1000, max_filesize=1100*1024*1024):
    ydl_opts = {
        'format': 'best',
        'noplaylist': True,
        'quiet': True,
        'progress_hooks': [progress_hook],
        'outtmpl': '%(title)s.%(ext)s'
    }

    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        info = ydl.extract_info(f"ytsearch20:{query}", download=False)
        videos = info.get("entries", [])

        candidates = []
        for v in videos:
            size = v.get("filesize") or v.get("filesize_approx")
            if size and size <= max_filesize:
                candidates.append((size, v))

        if not candidates:
            print("\033[0;31m❌ No videos found within ~1GB.\033[0m")
            return

        total_size = 0
        selected = []
        for size, v in sorted(candidates, key=lambda x: -x[0]):
            if total_size + size <= target_size_mb * 1024 * 1024:
                selected.append((size, v))
                total_size += size

        if not selected:
            print("\033[0;31m❌ No videos found close to 1GB.\033[0m")
            return

        filenames = []
        for size, video in selected:
            print(f"\033[0;34m🎬 Downloading: {video['title']} ({size/(1024*1024):.2f} MB)\033[0m")
            ydl.download([video['webpage_url']])
            filename = ydl.prepare_filename(video)
            filenames.append(filename)

        output_file = "combined_video.mp4"
        with open(output_file, "wb") as outfile:
            for fname in filenames:
                with open(fname, "rb") as infile:
                    outfile.write(infile.read())

        print(f"\033[0;32m✅ Video ready: {output_file} ({os.path.getsize(output_file)/(1024*1024):.2f} MB)\033[0m")
        for fname in filenames:
            os.remove(fname)  # Clean up individual files

def progress_hook(d):
    if d['status'] == 'downloading':
        p = d.get('_percent_str', '0%').strip()
        print(f"\r\033[0;34m⬇️ Progress: {p}\033[0m", end='')
    elif d['status'] == 'finished':
        print("\r\033[0;32m✅ Download completed\033[0m")

if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1:
        download_videos(sys.argv[1])
    else:
        print("\033[0;31mPlease provide a search query.\033[0m")
EOF

# Menu
while true; do
    clear
    echo -e "${BLUE}=== Pipe Network Menu ===${NC}"
    echo -e "${YELLOW}1. Install Node${NC}"
    echo -e "${YELLOW}2. Upload File${NC}"
    echo -e "${YELLOW}3. Show Uploaded File Info${NC}"
    echo -e "${YELLOW}4. Show Referral Stats and Code${NC}"
    echo -e "${YELLOW}5. Check Token Usage${NC}"
    echo -e "${YELLOW}6. Exit${NC}"
    read -p "$(echo -e ${YELLOW}Select an option: ${NC})" choice

    case $choice in
        1) install_node ;;
        2) upload_file ;;
        3) show_file_info ;;
        4) show_referral ;;
        5) check_token_usage ;;
        6) echo -e "${GREEN}Exiting...${NC}"; exit 0 ;;
        *) echo -e "${RED}Invalid option. Try again.${NC}"; sleep 1 ;;
    esac
done
