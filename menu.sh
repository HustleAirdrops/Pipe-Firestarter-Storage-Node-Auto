#!/bin/bash
# Color codes for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
BOLD='\033[1m'
CTRL_C_COUNT=0
IN_MENU=0
SOLANA_PUBKEY=""
LOG_DIR="$HOME/pipe_logs"
LOG_FILE="$LOG_DIR/pipe_manager_$(date +%Y%m%d_%H%M%S).log"

# Trap Ctrl+C
trap 'handle_ctrl_c' SIGINT

# Create log directory and file
mkdir -p "$LOG_DIR"
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

show_header() {
    clear
    echo -e "${BLUE}${BOLD}"
    echo "┌───────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐"
    echo "│ ██╗░░██╗██╗░░░██║░██████╗████████╗██╗░░░░░███████╗  ░█████╗░██╗██████╗░██████╗░██████╗░░█████╗░██████╗░░██████╗ │"
    echo "│ ██║░░██║██║░░░██║██╔════╝╚══██╔══╝██║░░░░░██╔════╝  ██╔══██╗██║██╔══██╗██╔══██╗██╔══██╗██╔══██╗██╔══██╗██╔════╝ │"
    echo "│ ███████║██║░░░██║╚█████╗░░░░██║░░░██║░░░░░█████╗░░  ███████║██║██████╔╝██║░░██║██████╔╝██║░░██║██████╔╝╚█████╗░ │"
    echo "│ ██╔══██║██║░░░██║░╚═══██╗░░░██║░░░██║░░░░░██╔══╝░░  ██╔══██║██║██╔══██╗██║░░██║██╔══██╗██║░░██║██╔═══╝░░╚═══██╗ │"
    echo "│ ██║░░██║╚██████╔╝██████╔╝░░░██║░░░███████╗███████╗  ██║░░██║██║██║░░██║██████╔╝██║░░██║╚█████╔╝██║░░░░░██████╔╝ │"
    echo "│ ╚═╝░░╚═╝░╚═════╝░╚═════╝░░░░╚═╝░░░╚══════╝╚══════╝  ╚═╝░░╚═╝╚═╝╚═╝░░╚═╝╚═════╝░╚═╝░░╚═╝░╚════╝░╚═╝░░░░░╚═════╝░ │"
    echo "└───────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘"
    echo -e "${YELLOW} 🚀 Pipe Node Manager by Aashish 🚀${NC}"
    echo -e "${YELLOW} GitHub: https://github.com/HustleAirdrops${NC}"
    echo -e "${YELLOW} Telegram: https://t.me/Hustle_Airdrops${NC}"
    echo -e "${GREEN}===============================================================================${NC}"
}

handle_ctrl_c() {
    ((CTRL_C_COUNT++))
    if [ $IN_MENU -eq 1 ]; then
        echo -e "${RED}🚨 Exiting...${NC}"
        exit 0
    fi
    if [ $CTRL_C_COUNT -ge 2 ]; then
        echo -e "${RED}🚨 Multiple Ctrl+C detected. Exiting...${NC}"
        exit 0
    fi
    echo -e "${RED}🚨 Ctrl+C detected. Returning to menu...${NC}"
    sleep 1
    return_to_menu
}

return_to_menu() {
    CTRL_C_COUNT=0
    echo -e "${YELLOW}🔁 Press Enter to return to menu...${NC}"
    read
}

setup_venv() {
    VENV_DIR="$HOME/pipe_venv"
    echo -e "${BLUE}🛠️ Setting up Python virtual environment at $VENV_DIR...${NC}"
    if ! command -v python3 >/dev/null 2>&1 || ! command -v pip3 >/dev/null 2>&1; then
        echo -e "${BLUE}📦 Installing Python3 and pip...${NC}"
        sudo apt update && sudo apt install -y python3 python3-pip python3-venv
        if [ $? -ne 0 ]; then
            echo -e "${RED}❌ Failed to install Python3 or pip!${NC}"
            return 1
        fi
    fi
    if [ ! -d "$VENV_DIR" ]; then
        python3 -m venv "$VENV_DIR"
        if [ $? -ne 0 ]; then
            echo -e "${RED}❌ Failed to create virtual environment!${NC}"
            return 1
        fi
    fi
    source "$VENV_DIR/bin/activate"
    pip install --upgrade pip
    for package in yt-dlp requests moviepy; do
        if ! pip show $package >/dev/null 2>&1; then
            echo -e "${YELLOW}📦 Installing $package...${NC}"
            RETRY_COUNT=0
            MAX_RETRIES=3
            while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
                pip install $package
                if [ $? -eq 0 ]; then
                    break
                fi
                ((RETRY_COUNT++))
                echo -e "${YELLOW}⚠️ Retry $RETRY_COUNT/$MAX_RETRIES for $package...${NC}"
                sleep 5
            done
            if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
                echo -e "${YELLOW}⚠️ Failed to install $package after $MAX_RETRIES attempts. Continuing without it...${NC}"
            fi
        fi
    done
    echo -e "${GREEN}✅ Python environment setup complete!${NC}"
    deactivate
}

setup_pipe_path() {
    if [ -f "$HOME/.cargo/bin/pipe" ]; then
        if ! grep -q "export PATH=\$HOME/.cargo/bin:\$PATH" ~/.bashrc; then
            echo 'export PATH=$HOME/.cargo/bin:$PATH' >> ~/.bashrc
            echo -e "${GREEN}✅ Added pipe path to ~/.bashrc.${NC}"
        fi
        export PATH=$HOME/.cargo/bin:$PATH
        source "$HOME/.cargo/env" 2>/dev/null
        chmod +x "$HOME/.cargo/bin/pipe" 2>/dev/null
        echo -e "${GREEN}✅ Pipe path configured and executable ensured.${NC}"
    else
        echo -e "${YELLOW}⚠️ Pipe binary not found. Triggering installation...${NC}"
        install_pipe
    fi
}

install_pipe() {
    echo -e "${BLUE}📥 Installing Pipe...${NC}"
    sudo apt update && sudo apt install -y curl build-essential git wget lz4 jq make gcc libgbm1 pkg-config libssl-dev tar clang bsdmainutils unzip libleveldb-dev libclang-dev ninja-build
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Failed to install dependencies!${NC}"
        return 1
    fi
    echo -e "${BLUE}🦀 Installing Rust...${NC}"
    curl https://sh.rustup.rs -sSf | sh -s -- -y
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Failed to install Rust!${NC}"
        return 1
    fi
    source "$HOME/.cargo/env"
    echo -e "${BLUE}📥 Cloning and installing Pipe...${NC}"
    git clone https://github.com/PipeNetwork/pipe.git "$HOME/pipe" || {
        echo -e "${RED}❌ Failed to clone Pipe repository!${NC}"
        return 1
    }
    cd "$HOME/pipe"
    cargo install --path .
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Failed to install Pipe!${NC}"
        cd "$HOME"
        return 1
        
    cd "$HOME"
    setup_pipe_path
    if ! command -v pipe >/dev/null 2>&1; then
        echo -e "${RED}❌ Pipe installation failed! Checking PATH: $PATH${NC}"
        return 1
    fi
    echo -e "${GREEN}✅ Pipe installed successfully!${NC}"

install_node() {
    echo -e "${BLUE}🔍 Checking if Pipe is already installed...${NC}"
    if command -v pipe >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Pipe is already installed! Checking configuration...${NC}"
    else
        install_pipe
        if [ $? -ne 0 ]; then
            echo -e "${RED}❌ Pipe installation failed. Please check logs in $LOG_FILE.${NC}"
            return_to_menu
            return
        fi
    fi
    sudo apt update && sudo apt install -y ffmpeg jq python3 python3-venv
    if ! command -v ffmpeg >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️ ffmpeg not found. Attempting to install...${NC}"
        sudo apt install -y ffmpeg
        if ! command -v ffmpeg >/dev/null 2>&1; then
            echo -e "${YELLOW}⚠️ Failed to install ffmpeg. Continuing without it...${NC}"
        else
            echo -e "${GREEN}✅ ffmpeg installed successfully.${NC}"
        fi
    fi
    if ! command -v jq >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️ jq not found. Attempting to install...${NC}"
        sudo apt install -y jq
        if ! command -v jq >/dev/null 2>&1; then
            echo -e "${YELLOW}⚠️ Failed to install jq. Continuing without it...${NC}"
        else
            echo -e "${GREEN}✅ jq installed successfully.${NC}"
        fi
    fi
    setup_venv
    if [ -f "$HOME/.pipe-cli.json" ]; then
        echo -e "${YELLOW}⚠️ Existing Pipe configuration found. Skipping user creation...${NC}"
        SOLANA_PUBKEY=$(jq -r '.solana_pubkey // "Not found"' "$HOME/.pipe-cli.json")
        return
    fi
    read -r -p "$(echo -e 👤 Enter your desired username: )" username
    echo -e "${BLUE}🆕 Creating new user...${NC}"
    pipe_output=$(pipe new-user "$username" 2>&1)
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Failed to create user: $pipe_output${NC}"
        return_to_menu
        return
    fi
    echo -e "${GREEN}✅ User created. Save these details:${NC}"
    echo "$pipe_output"
    SOLANA_PUBKEY=$(echo "$pipe_output" | grep "Solana Pubkey" | awk '{print $NF}')
    echo -e "${GREEN}🔑 Your Solana Public Key: $SOLANA_PUBKEY${NC}"
    if [ -n "$SOLANA_PUBKEY" ] && [ -f "$HOME/.pipe-cli.json" ]; then
        jq --arg sp "$SOLANA_PUBKEY" '. + {solana_pubkey: $sp}' "$HOME/.pipe-cli.json" > tmp.json && mv tmp.json "$HOME/.pipe-cli.json"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ Solana Public Key saved to ~/.pipe-cli.json${NC}"
        else
            echo -e "${RED}❌ Failed to save Solana Public Key to ~/.pipe-cli.json${NC}"
        fi
    else
        echo -e "${RED}❌ Could not save Solana Public Key: File or key not found.${NC}"
    fi
    echo -e "${BLUE}💾 Your credentials are below. Copy and save them, then press Enter to continue:${NC}"
    cat "$HOME/.pipe-cli.json" 2>/dev/null || echo -e "${RED}❌ Failed to display credentials file.${NC}"
    read -s -p "Press Enter after saving your credentials..."
    clear
    read -p "$(echo -e 🔗 Enter a referral code \(or press Enter to use my refer code 🥹\):)" referral_code
    if [ -z "$referral_code" ]; then
        referral_code="ITZMEAAS-PFJU"
        echo -e "${YELLOW}🔗 Using default referral code: $referral_code${NC}"
    fi
    echo -e "${BLUE}✅ Applying referral code...${NC}"
    pipe referral apply "$referral_code" || echo -e "${YELLOW}⚠️ Failed to apply referral code. Continuing...${NC}"
    pipe referral generate >/dev/null 2>&1 || echo -e "${YELLOW}⚠️ Failed to generate referral code. Continuing...${NC}"
}

auto_claim_faucet() {
    cat << 'EOF' > solana_airdrop.py
#!/usr/bin/env python3
import requests
import time
import uuid
RPC_URL = "https://api.devnet.solana.com"
LAMPORTS_PER_SOL = 1_000_000_000
DEFAULT_SOL = 5
def rpc(method: str, params):
    payload = {
        "jsonrpc": "2.0",
        "id": str(uuid.uuid4()),
        "method": method,
        "params": params
    }
    try:
        r = requests.post(RPC_URL, json=payload, timeout=30)
        r.raise_for_status()
        data = r.json()
        if "error" in data:
            raise RuntimeError(f"RPC error: {data['error']}")
        return data["result"]
    except requests.RequestException as e:
        raise RuntimeError("Network error: " + str(e))
def request_airdrop(pubkey: str, sol: float = DEFAULT_SOL) -> str:
    lamports = int(sol * LAMPORTS_PER_SOL)
    return rpc("requestAirdrop", [pubkey, lamports])
def wait_for_confirmation(signature: str, timeout_s: int = 45) -> bool:
    start = time.time()
    while time.time() - start < timeout_s:
        try:
            result = rpc("getSignatureStatuses", [[signature], {"searchTransactionHistory": True}])
            status = result["value"][0]
            if status and status.get("confirmationStatus") in ("confirmed", "finalized"):
                return True
        except:
            pass
        time.sleep(1.2)
    return False
def main(pubkey: str):
    try:
        print(f"Requesting airdrop of {DEFAULT_SOL} SOL to {pubkey} ...")
        sig = request_airdrop(pubkey, DEFAULT_SOL)
        print(f"Tx Signature: {sig}")
        print("Waiting for confirmation...")
        ok = wait_for_confirmation(sig)
        if ok:
            print("✅ Airdrop confirmed.")
            return True, sig
        else:
            print("⏱️ Timed out waiting for confirmation.")
            return False, "Timed out"
    except RuntimeError as e:
        return False, str(e)
    except Exception as e:
        raise RuntimeError("Network error: " + str(e))
if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1:
        success, message = main(sys.argv[1])
        print(message)
    else:
        print("Please provide a Solana public key.")
EOF
    chmod +x solana_airdrop.py
    if [ -z "$SOLANA_PUBKEY" ]; then
        SOLANA_PUBKEY=$(jq -r '.solana_pubkey // "Not found"' "$HOME/.pipe-cli.json" 2>/dev/null)
        if [ "$SOLANA_PUBKEY" = "Not found" ]; then
            echo -e "${RED}❌ Solana Public Key not found. Please run 'Install Node' first.${NC}"
            return_to_menu
            return
        fi
    fi
    retries=0
    max_retries=3
    while [ $retries -lt $max_retries ]; do
        attempt=$((retries+1))
        echo -e "${BLUE}💰 Attempting to claim 5 Devnet SOL (Attempt ${attempt}/${max_retries})...${NC}"
        result=$(python3 solana_airdrop.py "$SOLANA_PUBKEY" 2>&1)
        success=$(echo "$result" | grep -o "✅ Airdrop confirmed" | wc -l)
        message=$(echo "$result" | tail -n 1)
        if [ $success -eq 1 ]; then
            echo -e "${GREEN}✅ Airdrop successful. Tx: $message${NC}"
            rm -f solana_airdrop.py
            return 0
        else
            echo -e "${YELLOW}⚠️ Airdrop failed: $message${NC}"
            retries=$((retries+1))
            sleep 5
        fi
    done
    rm -f solana_airdrop.py
    echo -e "${YELLOW}⚠️ Auto claim failed after $max_retries attempts.${NC}"
    echo -e "${YELLOW}💰 Please claim 5 Devnet SOL manually from https://faucet.solana.com/ using your Solana Public Key: $SOLANA_PUBKEY${NC}"
    read -r -p "✅ Enter 'yes' to confirm you have claimed the SOL: " confirmation
    if [ "$confirmation" != "yes" ]; then
        echo -e "${RED}❌ SOL not claimed. Exiting.${NC}"
        exit 1
    fi
}

perform_swap() {
    if [ -z "$SOLANA_PUBKEY" ]; then
        SOLANA_PUBKEY=$(jq -r '.solana_pubkey // "Not found"' "$HOME/.pipe-cli.json" 2>/dev/null)
        if [ "$SOLANA_PUBKEY" = "Not found" ]; then
            echo -e "${RED}❌ Solana Public Key not found. Please run 'Install Node' first.${NC}"
            return_to_menu
            return
        fi
    fi
    retries=0
    max_retries=3
    while [ $retries -lt $max_retries ]; do
        attempt=$((retries+1))
        echo -e "${BLUE}⏳ Waiting 10 seconds before swapping (Attempt ${attempt}/${max_retries})...${NC}"
        sleep 10
        echo -e "${BLUE}🔄 Swapping 2 SOL for PIPE...${NC}"
        swap_output=$(pipe swap-sol-for-pipe 2 2>&1)
        if [ $? -eq 0 ]; then
            echo "$swap_output"
            echo -e "${GREEN}✅ Swap successful.${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠️ Failed to swap SOL for PIPE: $swap_output${NC}"
            retries=$((retries+1))
            sleep 5
        fi
    done
    echo -e "${RED}❌ Swap failed after $max_retries attempts. Please try again later or check your SOL balance at https://faucet.solana.com/.${NC}"
    return_to_menu
}

upload_file() {
    VENV_DIR="$HOME/pipe_venv"
    if [ ! -d "$VENV_DIR" ]; then
        setup_venv
    fi
    source "$VENV_DIR/bin/activate"
    available_sources=("manual")
    if pip show yt-dlp >/dev/null 2>&1; then available_sources+=("youtube"); fi
    if pip show requests >/dev/null 2>&1; then available_sources+=("pixabay" "pexels"); fi
    if [ ${#available_sources[@]} -eq 1 ]; then
        echo -e "${YELLOW}⚠️ No download sources available (yt-dlp or requests not installed). Only manual upload is available.${NC}"
    fi
    if ! command -v ffmpeg >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️ ffmpeg is not installed. Attempting to install...${NC}"
        sudo apt update && sudo apt install -y ffmpeg
        if ! command -v ffmpeg >/dev/null 2>&1; then
            echo -e "${YELLOW}⚠️ Failed to install ffmpeg. Continuing without it...${NC}"
        else
            echo -e "${GREEN}✅ ffmpeg installed successfully.${NC}"
        fi
    fi
    if ! command -v pipe >/dev/null 2>&1; then
        setup_pipe_path
        if ! command -v pipe >/dev/null 2>&1; then
            echo -e "${RED}❌ Pipe command not found. Attempting to install...${NC}"
            install_pipe
            if ! command -v pipe >/dev/null 2>&1; then
                echo -e "${RED}❌ Pipe installation failed. Please check logs in $LOG_FILE.${NC}"
                deactivate
                return_to_menu
                return
            fi
        fi
    fi
    while true; do
        clear
        show_header
        echo -e "${BLUE}${BOLD}======================= Upload File Submenu =======================${NC}"
        for i in "${!available_sources[@]}"; do
            case ${available_sources[$i]} in
                "youtube") echo -e "${YELLOW}$((i+1)). 📹 Upload from YouTube (yt-dlp)${NC}" ;;
                "pixabay") echo -e "${YELLOW}$((i+1)). 🎥 Upload from Pixabay${NC}" ;;
                "pexels") echo -e "${YELLOW}$((i+1)). 📽️ Upload from Pexels${NC}" ;;
                "manual") echo -e "${YELLOW}$((i+1)). 🗂️ Manual Upload (from home or pipe folder)${NC}" ;;
            esac
        done
        echo -e "${YELLOW}$(( ${#available_sources[@]} + 1 )). 🔙 Back to Main Menu${NC}"
        echo -e "${BLUE}=================================================================${NC}"
        read -p "$(echo -e Select an option: )" subchoice
        if [ "$subchoice" -eq $(( ${#available_sources[@]} + 1 )) ]; then
            deactivate
            return
        fi
        if [[ ! "$subchoice" =~ ^[0-9]+$ ]] || [ "$subchoice" -lt 1 ] || [ "$subchoice" -gt ${#available_sources[@]} ]; then
            echo -e "${RED}❌ Invalid option. Try again.${NC}"
            sleep 1
            continue
        fi
        source_type=${available_sources[$((subchoice-1))]}
        case $source_type in
            youtube)
                read -p "$(echo -e 🔍 Enter a search query for the video \(e.g., 'random full hd'\): )" query
                echo -e "${BLUE}📥 Downloading video from YouTube...${NC}"
                random_suffix=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
                output_file="video_$random_suffix.mp4"
                python3 video_downloader.py "$query" "$output_file" 2>&1 | tee -a "$LOG_FILE"
                ;;
            pixabay)
                API_KEY_FILE="$HOME/.pixabay_api_key"
                if [ ! -f "$API_KEY_FILE" ]; then
                    echo "pexels: iur1f5KGwvSIR1xr8I1t3KR3NP88wFXeCyV12ibHnioNXQYTy95KhE69" > "$API_KEY_FILE"
                    echo -e "${GREEN}✅ Default Pixabay API key set.${NC}"
                fi
                read -p "$(echo -e 🔍 Enter a search query for the video \(e.g., 'nature'\): )" query
                echo -e "${BLUE}📥 Downloading video from Pixabay...${NC}"
                random_suffix=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
                output_file="video_$random_suffix.mp4"
                python3 pixabay_downloader.py "$query" "$output_file" 2>&1 | tee -a "$LOG_FILE"
                ;;
            pexels)
                API_KEY_FILE="$HOME/.pexels_api_key"
                if [ ! -f "$API_KEY_FILE" ]; then
                    echo "51848865-07253475f9fc0309b02c38a39" > "$API_KEY_FILE"
                    echo -e "${GREEN}✅ Default Pexels API key set.${NC}"
                fi
                read -p "$(echo -e 🔍 Enter a search query for the video \(e.g., 'nature'\): )" query
                echo -e "${BLUE}📥 Downloading video from Pexels...${NC}"
                random_suffix=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
                output_file="video_$random_suffix.mp4"
                python3 pexels_downloader.py "$query" "$output_file" 2>&1 | tee -a "$LOG_FILE"
                ;;
            manual)
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
                read -p "$(echo -e Select a number: )" num
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
        esac
        if [ -f "$output_file" ] || [ "$source_type" = "manual" ]; then
            if [ "$source_type" = "manual" ]; then
                file_to_upload="$selected"
            else
                file_to_upload="$output_file"
            fi
            echo -e "${BLUE}⬆️ Uploading video...${NC}"
            retries=0
            max_retries=3
            while [ $retries -lt $max_retries ]; do
                attempt=$((retries+1))
                echo -e "${BLUE}📤 Upload attempt ${attempt}/${max_retries}...${NC}"
                upload_output=$(pipe upload-file "$file_to_upload" "$output_file" 2>&1)
                if [ $? -eq 0 ]; then
                    echo "$upload_output" | tee -a "$LOG_FILE"
                    file_id=$(echo "$upload_output" | grep "File ID (Blake3)" | awk '{print $NF}')
                    link_output=$(pipe create-public-link "$output_file" 2>&1)
                    if [ $? -eq 0 ]; then
                        echo "$link_output" | tee -a "$LOG_FILE"
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
                            if [ $? -eq 0 ]; then
                                echo -e "${GREEN}✅ File details saved successfully.${NC}"
                            else
                                echo -e "${YELLOW}⚠️ Failed to save file details to file_details.json${NC}"
                            fi
                            if [ "$source_type" != "manual" ]; then
                                echo -e "${BLUE}🗑️ Deleting local video file...${NC}"
                                rm -f "$output_file"
                            fi
                            break
                        else
                            echo -e "${YELLOW}⚠️ Failed to extract File ID.${NC}"
                        fi
                    else
                        echo -e "${YELLOW}⚠️ Failed to create public link: $link_output${NC}"
                    fi
                else
                    echo -e "${YELLOW}⚠️ Upload failed: $upload_output${NC}"
                fi
                retries=$((retries+1))
                sleep 5
            done
            if [ $retries -eq $max_retries ]; then
                echo -e "${RED}❌ Upload failed after $max_retries attempts. Check logs in $LOG_FILE.${NC}"
                if [ "$source_type" != "manual" ]; then
                    rm -f "$output_file" 2>/dev/null
                fi
            fi
        else
            echo -e "${YELLOW}⚠️ No video file found. Download may have failed or been canceled.${NC}"
        fi
        return_to_menu
    done
    deactivate
}

show_file_info() {
    echo -e "${BLUE}📄 Uploaded File Details:${NC}"
    if [ -f "file_details.json" ]; then
        count=$(jq '. | length' file_details.json 2>/dev/null || echo 0)
        if [ "$count" -eq 0 ]; then
            echo -e "${YELLOW}⚠️ No file details found in file_details.json.${NC}"
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
        echo -e "${YELLOW}⚠️ No file details found.${NC}"
    fi
    return_to_menu
}

show_credentials() {
    echo -e "${BLUE}🔑 Pipe Credentials:${NC}"
    if [ -f "$HOME/.pipe-cli.json" ]; then
        user_id=$(jq -r '.user_id // "Not found"' "$HOME/.pipe-cli.json")
        user_app_key=$(jq -r '.user_app_key // "Not found"' "$HOME/.pipe-cli.json")
        username=$(jq -r '.username // "Not found"' "$HOME/.pipe-cli.json")
        access_token=$(jq -r '.auth_tokens.access_token // "Not found"' "$HOME/.pipe-cli.json")
        refresh_token=$(jq -r '.auth_tokens.refresh_token // "Not found"' "$HOME/.pipe-cli.json")
        token_type=$(jq -r '.auth_tokens.token_type // "Not found"' "$HOME/.pipe-cli.json")
        expires_in=$(jq -r '.auth_tokens.expires_in // "Not found"' "$HOME/.pipe-cli.json")
        expires_at=$(jq -r '.auth_tokens.expires_at // "Not found"' "$HOME/.pipe-cli.json")
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
        echo -e "${YELLOW}⚠️ Credentials file (~/.pipe-cli.json) not found.${NC}"
    fi
    return_to_menu
}

show_referral() {
    echo -e "${BLUE}📊 Your referral stats:${NC}"
    pipe referral show 2>&1 | tee -a "$LOG_FILE" || echo -e "${YELLOW}⚠️ Failed to retrieve referral stats.${NC}"
    return_to_menu
}

swap_tokens() {
    if [ -z "$SOLANA_PUBKEY" ]; then
        SOLANA_PUBKEY=$(jq -r '.solana_pubkey // "Not found"' "$HOME/.pipe-cli.json" 2>/dev/null)
        if [ "$SOLANA_PUBKEY" = "Not found" ]; then
            echo -e "${RED}❌ Solana Public Key not found. Please run 'Install Node' first.${NC}"
            return_to_menu
            return
        fi
    fi
    echo -e "${BLUE}🔥 PIPE Swapping Menu${NC}"
    read -p "Enter amount to swap (default 2 SOL): " AMOUNT
    AMOUNT=${AMOUNT:-2}
    if [[ ! "$AMOUNT" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        echo -e "${RED}❌ Invalid amount. Must be a number.${NC}"
        return_to_menu
        return
    fi
    retries=0
    max_retries=3
    while [ $retries -lt $max_retries ]; do
        attempt=$((retries+1))
        echo -e "${BLUE}🔄 Swapping $AMOUNT SOL for PIPE (Attempt ${attempt}/${max_retries})...${NC}"
        swap_output=$(pipe swap-sol-for-pipe "$AMOUNT" 2>&1)
        if [ $? -eq 0 ]; then
            echo "$swap_output" | tee -a "$LOG_FILE"
            echo -e "${GREEN}✅ Successfully swapped $AMOUNT SOL for PIPE!${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠️ Swap failed: $swap_output${NC}"
            retries=$((retries+1))
            sleep 5
        fi
    done
    echo -e "${RED}❌ Swap failed after $max_retries attempts. Please check your SOL balance at https://faucet.solana.com/.${NC}"
    return_to_menu
}

check_token_usage() {
    echo -e "${BLUE}📈 Checking token usage...${NC}"
    pipe token-usage 2>&1 | tee -a "$LOG_FILE" || echo -e "${YELLOW}⚠️ Failed to check token usage.${NC}"
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
import shutil
try:
    from moviepy.editor import VideoFileClip, concatenate_videoclips
    MOVIEPY_AVAILABLE = True
except ImportError:
    MOVIEPY_AVAILABLE = False
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
def check_ffmpeg():
    return shutil.which("ffmpeg") is not None
def concatenate_with_moviepy(files, output_file):
    if not MOVIEPY_AVAILABLE:
        print("⚠️ moviepy is not installed. Cannot concatenate with moviepy.")
        return False
    try:
        clips = []
        for fn in files:
            if os.path.exists(fn) and os.path.getsize(fn) > 0:
                try:
                    clip = VideoFileClip(fn)
                    clips.append(clip)
                except Exception as e:
                    print(f"⚠️ Skipping invalid file {fn}: {str(e)}")
        if not clips:
            print("⚠️ No valid video clips to concatenate.")
            return False
        final_clip = concatenate_videoclips(clips, method="compose")
        final_clip.write_videofile(output_file, codec="libx264", audio_codec="aac", temp_audiofile="temp-audio.m4a", remove_temp=True, threads=2)
        for clip in clips:
            clip.close()
        final_clip.close()
        return os.path.exists(output_file) and os.path.getsize(output_file) > 0
    except Exception as e:
        print(f"⚠️ Moviepy concatenation failed: {str(e)}")
        return False
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
    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(f"ytsearch20:{query}", download=False)
            videos = info.get("entries", [])
            candidates = []
            for v in videos:
                size = v.get("filesize") or v.get("filesize_approx")
                if size and min_filesize <= size <= max_filesize:
                    candidates.append((size, v))
            if not candidates:
                print("⚠️ No suitable videos found (at least 50MB and up to ~1GB).")
                return
            for size, v in sorted(candidates, key=lambda x: -x[0]):
                if total_size + size <= target_size_mb * 1024 * 1024:
                    total_size += size
                    current_file = len(downloaded_files) + 1
                    print(f"🎬 Downloading video {current_file}: {v['title']} ({format_size(size)})")
                    ydl.download([v['webpage_url']])
                    filename = ydl.prepare_filename(v)
                    if os.path.exists(filename) and os.path.getsize(filename) > 0:
                        downloaded_files.append(filename)
                        total_downloaded += size
                    else:
                        print(f"⚠️ Failed to download or empty file: {filename}")
                        continue
                    elapsed = time.time() - start_time
                    speed = total_downloaded / (1024*1024*elapsed) if elapsed > 0 else 0
                    eta = (total_size - total_downloaded) / (speed * 1024*1024) if speed > 0 else 0
                    print(f"✅ Overall Progress: {draw_progress_bar(total_downloaded, total_size)} "
                          f"({format_size(total_downloaded)}/{format_size(total_size)}) "
                          f"Speed: {speed:.2f} MB/s ETA: {format_time(eta)}")
        if not downloaded_files:
            print("⚠️ No videos found close to 1GB.")
            return
        if len(downloaded_files) == 1:
            os.rename(downloaded_files[0], output_file)
        else:
            success = False
            if check_ffmpeg():
                print("🔗 Concatenating videos with ffmpeg...")
                with open('list.txt', 'w') as f:
                    for fn in downloaded_files:
                        f.write(f"file '{fn}'\n")
                result = subprocess.run(['ffmpeg', '-f', 'concat', '-safe', '0', '-i', 'list.txt', '-c', 'copy', output_file], capture_output=True, text=True)
                if result.returncode == 0 and os.path.exists(output_file) and os.path.getsize(output_file) > 0:
                    success = True
                else:
                    print(f"⚠️ ffmpeg concatenation failed: {result.stderr}")
                if os.path.exists('list.txt'):
                    os.remove('list.txt')
            if not success:
                print("🔗 Falling back to moviepy for concatenation...")
                success = concatenate_with_moviepy(downloaded_files, output_file)
            if not success:
                print("⚠️ Concatenation failed. Using first video only.")
                os.rename(downloaded_files[0], output_file)
                downloaded_files = downloaded_files[1:]
            for fn in downloaded_files:
                if os.path.exists(fn):
                    os.remove(fn)
        if os.path.exists(output_file) and os.path.getsize(output_file) > 0:
            print(f"✅ Video ready: {output_file} ({format_size(os.path.getsize(output_file))})")
        else:
            print("⚠️ Failed to create final video file.")
    except Exception as e:
        print(f"⚠️ An error occurred: {str(e)}")
        for fn in downloaded_files:
            if os.path.exists(fn):
                os.remove(fn)
        if os.path.exists('list.txt'):
            os.remove('list.txt')
def progress_hook(d):
    if d['status'] == 'downloading':
        downloaded = d.get('downloaded_bytes', 0)
        total = d.get('total_bytes', d.get('total_bytes_estimate', 1000000))
        speed = d.get('speed', 0) or 0
        eta = d.get('eta', 0) or 0
        print(f"\r⬇️ File Progress: {draw_progress_bar(downloaded, total)} "
              f"({format_size(downloaded)}/{format_size(total)}) "
              f"Speed: {speed/(1024*1024):.2f} MB/s ETA: {format_time(eta)}", end='')
    elif d['status'] == 'finished':
        print("\r✅ File Download completed")
if __name__ == "__main__":
    if len(sys.argv) > 2:
        download_videos(sys.argv[1], sys.argv[2])
    else:
        print("Please provide a search query and output filename.")
EOF

cat << 'EOF' > pixabay_downloader.py
import requests
import os
import sys
import time
import random
import string
import subprocess
import shutil
try:
    from moviepy.editor import VideoFileClip, concatenate_videoclips
    MOVIEPY_AVAILABLE = True
except ImportError:
    MOVIEPY_AVAILABLE = False
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
def check_ffmpeg():
    return shutil.which("ffmpeg") is not None
def concatenate_with_moviepy(files, output_file):
    if not MOVIEPY_AVAILABLE:
        print("⚠️ moviepy is not installed. Cannot concatenate with moviepy.")
        return False
    try:
        clips = []
        for fn in files:
            if os.path.exists(fn) and os.path.getsize(fn) > 0:
                try:
                    clip = VideoFileClip(fn)
                    clips.append(clip)
                except Exception as e:
                    print(f"⚠️ Skipping invalid file {fn}: {str(e)}")
        if not clips:
            print("⚠️ No valid video clips to concatenate.")
            return False
        final_clip = concatenate_videoclips(clips, method="compose")
        final_clip.write_videofile(output_file, codec="libx264", audio_codec="aac", temp_audiofile="temp-audio.m4a", remove_temp=True, threads=2)
        for clip in clips:
            clip.close()
        final_clip.close()
        return os.path.exists(output_file) and os.path.getsize(output_file) > 0
    except Exception as e:
        print(f"⚠️ Moviepy concatenation failed: {str(e)}")
        return False
def download_videos(query, output_file, target_size_mb=1000):
    api_key_file = os.path.expanduser('~/.pixabay_api_key')
    if not os.path.exists(api_key_file):
        print("⚠️ Pixabay API key file not found.")
        return
    with open(api_key_file, 'r') as f:
        api_key = f.read().strip()
    per_page = 100
    try:
        url = f"https://pixabay.com/api/videos/?key={api_key}&q={query}&per_page={per_page}&min_width=1920&min_height=1080&video_type=all"
        resp = requests.get(url, timeout=10)
        if resp.status_code != 200:
            print(f"⚠️ Error fetching Pixabay API: {resp.text}")
            return
        data = resp.json()
        videos = data.get('hits', [])
        if not videos:
            print("⚠️ No videos found for query.")
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
            print(f"🎬 Downloading video {i+1}: {v['tags']} ({v['duration']}s)")
            resp = requests.get(video_url, stream=True, timeout=10)
            size = int(resp.headers.get('content-length', 0))
            if size < 50 * 1024 * 1024:
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
                        print(f"\r⬇️ File Progress: {draw_progress_bar(downloaded, size)} "
                              f"({format_size(downloaded)}/{format_size(size)}) "
                              f"Speed: {speed:.2f} MB/s ETA: {format_time(eta)}", end='')
            print("\r✅ File Download completed")
            file_size = os.path.getsize(filename) if os.path.exists(filename) else 0
            if file_size == 0:
                if os.path.exists(filename):
                    os.remove(filename)
                continue
            total_size += file_size
            total_downloaded += file_size
            downloaded_files.append(filename)
            if total_size >= target_size_mb * 1024 * 1024:
                break
        if not downloaded_files:
            print("⚠️ No suitable videos downloaded.")
            return
        if len(downloaded_files) == 1:
            os.rename(downloaded_files[0], output_file)
        else:
            success = False
            if check_ffmpeg():
                print("🔗 Concatenating videos with ffmpeg...")
                with open('list.txt', 'w') as f:
                    for fn in downloaded_files:
                        f.write(f"file '{fn}'\n")
                result = subprocess.run(['ffmpeg', '-f', 'concat', '-safe', '0', '-i', 'list.txt', '-c', 'copy', output_file], capture_output=True, text=True)
                if result.returncode == 0 and os.path.exists(output_file) and os.path.getsize(output_file) > 0:
                    success = True
                else:
                    print(f"⚠️ ffmpeg concatenation failed: {result.stderr}")
                if os.path.exists('list.txt'):
                    os.remove('list.txt')
            if not success:
                print("🔗 Falling back to moviepy for concatenation...")
                success = concatenate_with_moviepy(downloaded_files, output_file)
            if not success:
                print("⚠️ Concatenation failed. Using first video only.")
                os.rename(downloaded_files[0], output_file)
                downloaded_files = downloaded_files[1:]
            for fn in downloaded_files:
                if os.path.exists(fn):
                    os.remove(fn)
        if os.path.exists(output_file) and os.path.getsize(output_file) > 0:
            print(f"✅ Video ready: {output_file} ({format_size(os.path.getsize(output_file))})")
        else:
            print("⚠️ Failed to create final video file.")
    except Exception as e:
        print(f"⚠️ An error occurred: {str(e)}")
        for fn in downloaded_files:
            if os.path.exists(fn):
                os.remove(fn)
        if os.path.exists('list.txt'):
            os.remove('list.txt')
if __name__ == "__main__":
    if len(sys.argv) > 2:
        download_videos(sys.argv[1], sys.argv[2])
    else:
        print("Please provide a search query and output filename.")
EOF

cat << 'EOF' > pexels_downloader.py
import requests
import os
import sys
import time
import random
import string
import subprocess
import shutil
try:
    from moviepy.editor import VideoFileClip, concatenate_videoclips
    MOVIEPY_AVAILABLE = True
except ImportError:
    MOVIEPY_AVAILABLE = False
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
def check_ffmpeg():
    return shutil.which("ffmpeg") is not None
def concatenate_with_moviepy(files, output_file):
    if not MOVIEPY_AVAILABLE:
        print("⚠️ moviepy is not installed. Cannot concatenate with moviepy.")
        return False
    try:
        clips = []
        for fn in files:
            if os.path.exists(fn) and os.path.getsize(fn) > 0:
                try:
                    clip = VideoFileClip(fn)
                    clips.append(clip)
                except Exception as e:
                    print(f"⚠️ Skipping invalid file {fn}: {str(e)}")
        if not clips:
            print("⚠️ No valid video clips to concatenate.")
            return False
        final_clip = concatenate_videoclips(clips, method="compose")
        final_clip.write_videofile(output_file, codec="libx264", audio_codec="aac", temp_audiofile="temp-audio.m4a", remove_temp=True, threads=2)
        for clip in clips:
            clip.close()
        final_clip.close()
        return os.path.exists(output_file) and os.path.getsize(output_file) > 0
    except Exception as e:
        print(f"⚠️ Moviepy concatenation failed: {str(e)}")
        return False
def download_videos(query, output_file, target_size_mb=1000):
    api_key_file = os.path.expanduser('~/.pexels_api_key')
    if not os.path.exists(api_key_file):
        print("⚠️ Pexels API key file not found.")
        return
    with open(api_key_file, 'r') as f:
        api_key = f.read().strip()
    per_page = 80
    try:
        headers = {'Authorization': api_key}
        url = f"https://api.pexels.com/videos/search?query={query}&per_page={per_page}&min_width=1920&min_height=1080"
        resp = requests.get(url, headers=headers, timeout=10)
        if resp.status_code != 200:
            print(f"⚠️ Error fetching Pexels API: {resp.text}")
            return
        data = resp.json()
        videos = data.get('videos', [])
        if not videos:
            print("⚠️ No videos found for query.")
            return
        videos.sort(key=lambda x: x['duration'], reverse=True)
        downloaded_files = []
        total_size = 0
        total_downloaded = 0
        start_time = time.time()
        for i, v in enumerate(videos):
            video_files = v.get('video_files', [])
            video_url = None
            for file in video_files:
                if file['width'] >= 1920 and file['height'] >= 1080:
                    video_url = file['link']
                    break
            if not video_url:
                continue
            filename = f"pex_{i}_{''.join(random.choices(string.ascii_letters + string.digits, k=8))}.mp4"
            print(f"🎬 Downloading video {i+1}: {v['id']} ({v['duration']}s)")
            resp = requests.get(video_url, stream=True, timeout=10)
            size = int(resp.headers.get('content-length', 0))
            if size < 50 * 1024 * 1024:
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
                        print(f"\r⬇️ File Progress: {draw_progress_bar(downloaded, size)} "
                              f"({format_size(downloaded)}/{format_size(size)}) "
                              f"Speed: {speed:.2f} MB/s ETA: {format_time(eta)}", end='')
            print("\r✅ File Download completed")
            file_size = os.path.getsize(filename) if os.path.exists(filename) else 0
            if file_size == 0:
                if os.path.exists(filename):
                    os.remove(filename)
                continue
            total_size += file_size
            total_downloaded += file_size
            downloaded_files.append(filename)
            if total_size >= target_size_mb * 1024 * 1024:
                break
        if not downloaded_files:
            print("⚠️ No suitable videos downloaded.")
            return
        if len(downloaded_files) == 1:
            os.rename(downloaded_files[0], output_file)
        else:
            success = False
            if check_ffmpeg():
                print("🔗 Concatenating videos with ffmpeg...")
                with open('list.txt', 'w') as f:
                    for fn in downloaded_files:
                        f.write(f"file '{fn}'\n")
                result = subprocess.run(['ffmpeg', '-f', 'concat', '-safe', '0', '-i', 'list.txt', '-c', 'copy', output_file], capture_output=True, text=True)
                if result.returncode == 0 and os.path.exists(output_file) and os.path.getsize(output_file) > 0:
                    success = True
                else:
                    print(f"⚠️ ffmpeg concatenation failed: {result.stderr}")
                if os.path.exists('list.txt'):
                    os.remove('list.txt')
            if not success:
                print("🔗 Falling back to moviepy for concatenation...")
                success = concatenate_with_moviepy(downloaded_files, output_file)
            if not success:
                print("⚠️ Concatenation failed. Using first video only.")
                os.rename(downloaded_files[0], output_file)
                downloaded_files = downloaded_files[1:]
            for fn in downloaded_files:
                if os.path.exists(fn):
                    os.remove(fn)
        if os.path.exists(output_file) and os.path.getsize(output_file) > 0:
            print(f"✅ Video ready: {output_file} ({format_size(os.path.getsize(output_file))})")
        else:
            print("⚠️ Failed to create final video file.")
    except Exception as e:
        print(f"⚠️ An error occurred: {str(e)}")
        for fn in downloaded_files:
            if os.path.exists(fn):
                os.remove(fn)
        if os.path.exists('list.txt'):
            os.remove('list.txt')
if __name__ == "__main__":
    if len(sys.argv) > 2:
        download_videos(sys.argv[1], sys.argv[2])
    else:
        print("Please provide a search query and output filename.")
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
    echo -e "${YELLOW}7. 🔥 Swap Tokens${NC}"
    echo -e "${YELLOW}8. ❌ Exit${NC}"
    echo -e "${BLUE}=============================================================================${NC}"
    IN_MENU=1
    read -p "$(echo -e Select an option: )" choice
    IN_MENU=0
    case $choice in
        1)
           install_node
           auto_claim_faucet
           perform_swap
           ;;
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
