#!/usr/bin/env bash

# NovaBackuper - Interactive x-ui backup installer
# Author: @power0matin
# Version: v1.0.0

set -Eeuo pipefail

#######################################
#            Global constants         #
#######################################

readonly PROJECT_NAME="NovaBackuper"
readonly VERSION="v1.0.0"
readonly OWNER="@power0matin"

readonly SCRIPT_SUFFIX="_backuper_script.sh"
readonly TAG="_backuper."
readonly BACKUP_SUFFIX="${TAG}zip"
readonly SPLIT_SIZE="49m"   # per-part size for zip split

#######################################
#           ANSI color codes          #
#######################################

declare -A COLORS=(
  [red]='\033[1;31m'      [pink]='\033[1;35m' 
  [green]='\033[1;92m'    [spring]='\033[38;5;46m'
  [orange]='\033[1;38;5;208m' [cyan]='\033[1;36m'
  [reset]='\033[0m'
)

#######################################
#       Logging & helper functions    #
#######################################

print()   { echo -e "${COLORS[cyan]}$*${COLORS[reset]}"; }
log()     { echo -e "${COLORS[cyan]}[INFO]${COLORS[reset]} $*"; }
warn()    { echo -e "${COLORS[orange]}[WARN]${COLORS[reset]} $*" >&2; }
error()   { echo -e "${COLORS[red]}[ERROR]${COLORS[reset]} $*" >&2; exit 1; }
wrong()   { echo -e "${COLORS[red]}[WRONG]${COLORS[reset]} $*" >&2; }
success() { echo -e "${COLORS[spring]}${COLORS[green]}[SUCCESS]${COLORS[reset]} $*"; }

input()   { read -p "$(echo -e "${COLORS[orange]}▶ $1${COLORS[reset]} ")" "$2"; }
confirm() { read -p "$(echo -e "${COLORS[pink]}Press any key to continue...${COLORS[reset]}")"; }

trap 'error "Unexpected error at line ${LINENO}: ${BASH_COMMAND}"' ERR

#######################################
#           System utilities          #
#######################################

check_root() {
  [[ $EUID -eq 0 ]] || error "This script must be run as root"
}

detect_package_manager() {
  if command -v apt-get &>/dev/null; then
    echo "apt"
  elif command -v dnf &>/dev/null; then
    echo "dnf"
  elif command -v yum &>/dev/null; then
    echo "yum"
  elif command -v pacman &>/dev/null; then
    echo "pacman"
  else
    error "Unsupported package manager"
  fi
}

update_os() {
  local package_manager
  package_manager=$(detect_package_manager)
  log "Updating the system using $package_manager..."

  case $package_manager in
    apt)
      apt-get update -y && apt-get upgrade -y || error "Failed to update the system"
      ;;
    dnf|yum)
      $package_manager update -y || error "Failed to update the system"
      ;;
    pacman)
      pacman -Syu --noconfirm || error "Failed to update the system"
      ;;
  esac
  success "System updated successfully"
}

install_dependencies() {
  local package_manager
  package_manager=$(detect_package_manager)

  local cron_pkg=""
  case "$package_manager" in
    apt) cron_pkg="cron" ;;
    dnf|yum) cron_pkg="cronie" ;;
    pacman) cron_pkg="cronie" ;;
  esac

  # Minimal, actually-used dependencies
  local packages=("zip" "curl" "$cron_pkg" "ca-certificates" "tzdata")

  log "Installing dependencies: ${packages[*]}..."

  case "$package_manager" in
    apt)
      apt-get update -y || error "Failed to update apt cache"
      apt-get install -y "${packages[@]}" || error "Failed to install dependencies"
      ;;
    dnf|yum)
      $package_manager install -y "${packages[@]}" || error "Failed to install dependencies"
      ;;
    pacman)
      pacman -Sy --noconfirm "${packages[@]}" || error "Failed to install dependencies"
      ;;
  esac

  success "Dependencies installed successfully"
}

#######################################
#             Main menu               #
#######################################

menu() {
  install_dependencies

  while true; do
    clear
    print "======== ${PROJECT_NAME} Menu [${VERSION}] ========"
    print ""
    print "0) Update OS packages (optional)"
    print "1) Install NovaBackuper for x-ui"
    print "2) Edit existing backup"
    print "3) Update NovaBackuper"
    print "4) Remove all NovaBackuper scripts"
    print "5) Run all NovaBackuper backup scripts"
    print "6) Exit"
    print ""
    input "Choose an option:" choice

    case $choice in
      0)
        update_os
        confirm
        ;;
      1)
        start_backup
        ;;
      2)
        edit_backup
        ;;
      3)
        update_novabackuper
        ;;
      4)
        cleanup_backups
        ;;
      5)
        run_all_backup_scripts
        ;;
      6)
        print "Thank you for using ${PROJECT_NAME} by ${OWNER}. Goodbye!"
        exit 0
        ;;
      *)
        wrong "Invalid option, please select a valid number!"
        ;;
    esac
  done
}

cleanup_backups() {
  print "Removing all NovaBackuper scripts and related backup files..."

  rm -rf /root/*"$SCRIPT_SUFFIX" /root/*"$TAG"* /root/*_backuper.sh

  crontab -l 2>/dev/null | grep -v "$SCRIPT_SUFFIX" | crontab - || true

  success "All NovaBackuper scripts and cron jobs have been removed."
  sleep 1
}

run_all_backup_scripts() {
  local failed=0

  if compgen -G "/root/*${SCRIPT_SUFFIX}" > /dev/null; then
    for script in /root/*${SCRIPT_SUFFIX}; do
      log "Running backup script: $script"
      if ! bash "$script"; then
        warn "Backup script failed: $script"
        failed=$((failed + 1))
      fi
    done

    if [ "$failed" -gt 0 ]; then
      warn "Finished running scripts with ${failed} failure(s)."
    else
      success "All backup scripts ran successfully."
    fi
  else
    warn "No backup scripts found in /root directory"
  fi

  confirm
}

edit_backup() {
  clear
  print "[EDIT EXISTING BACKUP]\n"

  local scripts=()
  local path

  for path in /root/_*"${SCRIPT_SUFFIX}"; do
    [[ -f "$path" ]] || continue
    scripts+=("$path")
  done

  if (( ${#scripts[@]} == 0 )); then
    warn "No existing ${PROJECT_NAME} scripts found in /root."
    confirm
    return
  fi

  print "Available backup scripts:\n"
  local idx
  for idx in "${!scripts[@]}"; do
    local base remark
    base=$(basename "${scripts[$idx]}")
    remark=${base#_}
    remark=${remark%"$SCRIPT_SUFFIX"}
    printf "  %d) %s (remark: %s)\n" "$((idx + 1))" "$base" "$remark"
  done

  echo
  local choice
  while true; do
    input "Select a script to edit (1-${#scripts[@]}): " choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#scripts[@]} )); then
      wrong "Invalid selection."
    else
      break
    fi
  done

  local selected base
  selected="${scripts[$((choice - 1))]}"
  base=$(basename "$selected")

  REMARK=${base#_}
  REMARK=${REMARK%"$SCRIPT_SUFFIX"}

  success "Selected backup remark: ${REMARK}"

  # Remove old cron entry for this script
  crontab -l 2>/dev/null | grep -v "$selected" | crontab - || true

  # Remove old script file
  rm -f "$selected"
  success "Previous script and cron entry removed. Reconfiguring..."

  # Run wizard again for the same remark
  generate_timer
  check_xui
  telegram_progress
  generate_script
}

update_novabackuper() {
  clear
  print "[UPDATE]\n"

  local url="https://github.com/power0matin/NovaBackuper/raw/master/nova-backuper.sh"
  local target="/root/nova-backuper.sh"

  print "Downloading latest ${PROJECT_NAME}..."
  if curl -fsSL "$url" -o "${target}.tmp"; then
    mv "${target}.tmp" "$target"
    chmod +x "$target"
    success "NovaBackuper updated at: $target"
    print ""
    print "Restarting with the new version..."
    sleep 1
    exec bash "$target"
  else
    wrong "Failed to download latest script. Please check your network or GitHub access."
    rm -f "${target}.tmp" 2>/dev/null || true
    confirm
  fi
}

#######################################
#         Interactive wizard          #
#######################################

start_backup() {
  generate_remark
  generate_timer
  check_xui
  telegram_progress
  generate_script
}

generate_remark() {
  clear
  print "[REMARK]\n"
  print "We need a remark for the backup file (e.g., main, panel, prod_xui).\n"

  while true; do
    input "Enter a remark: " REMARK

    if ! [[ "$REMARK" =~ ^[a-zA-Z0-9_]+$ ]]; then
      wrong "Remark must contain only letters, numbers, or underscores."
    elif [ ${#REMARK} -lt 3 ]; then
      wrong "Remark must be at least 3 characters long."
    elif [ -e "/root/_${REMARK}${SCRIPT_SUFFIX}" ]; then
      wrong "File _${REMARK}${SCRIPT_SUFFIX} already exists. Choose a different remark."
    else
      success "Backup remark: $REMARK"
      break
    fi
  done
  sleep 1
}

generate_timer() {
  clear
  print "[TIMER]\n"
  print "Enter a time interval in minutes for sending backups."
  print "We will use a safe cron schedule + an internal interval gate for exact timing.\n"

  while true; do
    input "Enter the number of minutes (1-1440): " minutes

    if ! [[ "$minutes" =~ ^[0-9]+$ ]]; then
      wrong "Please enter a valid number."
    elif [ "$minutes" -lt 1 ] || [ "$minutes" -gt 1440 ]; then
      wrong "Number must be between 1 and 1440."
    else
      break
    fi
  done

  INTERVAL_MINUTES="$minutes"

  # Cron base frequency (avoid running too often if interval is large)
  # If interval < 5 => every 1 minute; else every 5 minutes.
  if [ "$INTERVAL_MINUTES" -lt 5 ]; then
    CRON_BASE_MINUTES=1
  else
    CRON_BASE_MINUTES=5
  fi

  TIMER="*/${CRON_BASE_MINUTES} * * * *"
  success "Internal interval: every ${INTERVAL_MINUTES} minutes"
  success "Cron schedule: ${TIMER} (script will self-skip until interval is due)"
  sleep 1
}

check_xui() {
  clear
  print "[X-UI PATH CHECK]\n"

  local XUI_DB_FOLDER="/etc/x-ui"

  if [ ! -d "$XUI_DB_FOLDER" ]; then
    error "Directory not found: $XUI_DB_FOLDER

Please make sure x-ui is installed and its config directory is /etc/x-ui."
  fi

  if [ ! -f "${XUI_DB_FOLDER}/x-ui.db" ]; then
    error "x-ui.db not found in $XUI_DB_FOLDER. Aborting."
  fi

  success "x-ui directory detected: $XUI_DB_FOLDER"
  XUI_DB_FOLDER_GLOBAL="$XUI_DB_FOLDER"
  sleep 1
}

telegram_progress() {
  clear
  print "[TELEGRAM CONFIG]\n"
  print "To use Telegram, you need to provide a bot token and a chat ID.\n"

  while true; do
    # Get bot token
    while true; do
      input "Enter the bot token: " BOT_TOKEN
      if [[ -z "$BOT_TOKEN" ]]; then
        wrong "Bot token cannot be empty!"
      elif [[ ! "$BOT_TOKEN" =~ ^[0-9]+:[a-zA-Z0-9_-]{35,}$ ]]; then
        wrong "Invalid bot token format!"
      else
        break
      fi
    done

    # Get chat ID
    while true; do
      input "Enter the chat ID: " CHAT_ID
      if [[ -z "$CHAT_ID" ]]; then
        wrong "Chat ID cannot be empty!"
      elif [[ ! "$CHAT_ID" =~ ^-?[0-9]+$ ]]; then
        wrong "Invalid chat ID format!"
      else
        break
      fi
    done

    while true; do
      input "Enter the topic ID (Press Enter to skip): " TOPIC_ID
      if [[ -z "$TOPIC_ID" ]]; then
        success "No topic ID provided. Messages will be sent to the main chat."
        TOPIC_ID=""
        break
      elif [[ ! "$TOPIC_ID" =~ ^[0-9]+$ ]]; then
        wrong "Invalid topic ID format! Must be a number."
      else
        success "Topic ID set: $TOPIC_ID"
        break
      fi
    done

    # ✅ Ask for timezone (IANA, e.g. Asia/Tehran)
    local default_tz="UTC"
    if command -v timedatectl >/dev/null 2>&1; then
      default_tz=$(timedatectl show -p Timezone --value 2>/dev/null || echo "UTC")
    fi

    while true; do
      input "Enter your timezone (e.g. Asia/Tehran for Tehran) [default: ${default_tz}]: " USER_TZ
      if [[ -z "$USER_TZ" ]]; then
        USER_TZ="$default_tz"
        break
      elif TZ="$USER_TZ" date >/dev/null 2>&1; then
        break
      else
        wrong "Invalid timezone. Example: Asia/Tehran, Europe/Berlin, America/New_York"
      fi
    done

    TIMEZONE="$USER_TZ"
    success "Using timezone: $TIMEZONE"

    # Validate bot token and chat ID
    log "Checking Telegram bot..."
    local response
    if [[ -n "$TOPIC_ID" ]]; then
      response=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
        "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d message_thread_id="$TOPIC_ID" \
        -d text="Hi from ${PROJECT_NAME} (test message)." )
    else
      response=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
        "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d text="Hi from ${PROJECT_NAME} (test message)." )
    fi

    if [[ "$response" -ne 200 ]]; then
      wrong "Invalid bot token, chat ID, topic ID, or Telegram API error! (HTTP $response)"
    else
      success "Bot token and chat ID are valid."
      break
    fi
  done

  TELEGRAM_BOT_TOKEN="$BOT_TOKEN"
  TELEGRAM_CHAT_ID="$CHAT_ID"
  TELEGRAM_TOPIC_ID="$TOPIC_ID"

  success "Telegram configuration completed successfully."
  sleep 1
}


#######################################
#           Script generator          #
#######################################

# Escape replacement text for sed (handles &, | and backslashes safely)
sed_escape() {
  # Escape: backslash, ampersand, and delimiter |
  printf '%s' "$1" | sed -e 's/[\\/&|]/\\&/g'
}

generate_script() {
  clear
  local BACKUP_PATH="/root/_${REMARK}${SCRIPT_SUFFIX}"

  log "Generating backup script: $BACKUP_PATH"

  cat <<'EOL' > "$BACKUP_PATH"
#!/usr/bin/env bash
set -Eeuo pipefail

# Auto-generated by ${PROJECT_NAME} (${VERSION})
# Remark: ${REMARK}

ip=$(hostname -I | awk '{print $1}')
timestamp=$(date +%m%d-%H%M)

REMARK="__REMARK__"
PROJECT_NAME="__PROJECT_NAME__"
VERSION="__VERSION__"

TAG="__TAG__"
BACKUP_SUFFIX="__BACKUP_SUFFIX__"
SPLIT_SIZE="__SPLIT_SIZE__"

XUI_DB_DIR="__XUI_DB_DIR__"
TIMEZONE="__TIMEZONE__"

TELEGRAM_BOT_TOKEN="__TG_BOT__"
TELEGRAM_CHAT_ID="__TG_CHAT__"
TELEGRAM_TOPIC_ID="__TG_TOPIC__"

INTERVAL_MINUTES="__INTERVAL_MINUTES__"

backup_name="/root/${timestamp}_${REMARK}${BACKUP_SUFFIX}"
base_name="/root/${timestamp}_${REMARK}${TAG}"


log()   { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

STATE_DIR="/var/lib/novabackuper"
LAST_RUN_FILE="${STATE_DIR}/${REMARK}.last_run"
LOCK_DIR="${STATE_DIR}/${REMARK}.lockdir"

mkdir -p "$STATE_DIR"

should_run_now() {
  local now last
  now=$(date +%s)

  if [ -f "$LAST_RUN_FILE" ]; then
    last=$(cat "$LAST_RUN_FILE" 2>/dev/null || echo 0)
    if [[ "$last" =~ ^[0-9]+$ ]]; then
      if (( now - last < INTERVAL_MINUTES * 60 )); then
        log "Skip: not due yet (interval ${INTERVAL_MINUTES}m)."
        return 1
      fi
    fi
  fi
  return 0
}

acquire_lock() {
  # mkdir-based lock (portable)
  if mkdir "$LOCK_DIR" 2>/dev/null; then
    trap 'rm -rf "$LOCK_DIR" 2>/dev/null || true' EXIT
    return 0
  fi
  log "Skip: another backup run is in progress."
  return 1
}

# Build caption dynamically at runtime
CAPTION="$(cat <<EOF
<b>🛡 ${PROJECT_NAME}</b>

🕒 <b>Time:</b> $(TZ="${TIMEZONE}" date '+%Y-%m-%d %H:%M:%S %:z') (<code>${TIMEZONE}</code>)
🖥 <b>Host:</b> <code>$(hostname)</code> [<code>${ip}</code>]
📦 <b>Backup ID:</b> <code>${timestamp}_${REMARK}</code>
📚 <b>Scope:</b> x-ui database (<code>x-ui.db</code> / <code>x-ui.db-wal</code> / <code>x-ui.db-shm</code>)
EOF
)"

# Trim leading/trailing empty lines (prevents the "blank first line" issue)
CAPTION="$(printf '%s' "$CAPTION" | sed -e '1{/^[[:space:]]*$/d;}' -e '${/^[[:space:]]*$/d;}')"

reply_markup='{"inline_keyboard":[[{"text":"📦 GitHub","url":"https://github.com/power0matin/NovaBackuper"},{"text":"👨‍💻 Developer","url":"https://github.com/power0matin"}]]}'

# Clean up old backup files (only specific backup files)
cd /root
shopt -s nullglob
for old in /root/*_"${REMARK}${TAG}"*; do
  rm -f -- "$old" 2>/dev/null || true
done
shopt -u nullglob

# Ensure x-ui database files exist
if [ ! -f "${XUI_DB_DIR}/x-ui.db" ]; then
  log "x-ui.db not found in ${XUI_DB_DIR}. Aborting."
  exit 1
fi

db_files=()

for f in "${XUI_DB_DIR}/x-ui.db" "${XUI_DB_DIR}/x-ui.db-wal" "${XUI_DB_DIR}/x-ui.db-shm"; do
  if [ -f "$f" ]; then
    db_files+=("$f")
  fi
done

if [ "${#db_files[@]}" -eq 0 ]; then
  log "No x-ui database files found in ${XUI_DB_DIR}. Aborting."
  exit 1
fi


acquire_lock || exit 0
should_run_now || exit 0

log "Creating backup archive: ${backup_name}"

log "Including files:"
printf '  - %s\n' "${db_files[@]}"

if ! zip -9 -r -s "${SPLIT_SIZE}" "$backup_name" "${db_files[@]}"; then
  log "Failed to compress ${REMARK} files. Please check the server."
  exit 1
fi


# Send backup files to Telegram
shopt -s nullglob
parts=( "${base_name}"* )
shopt -u nullglob

if [ "${#parts[@]}" -gt 0 ]; then
  for FILE in "${parts[@]}"; do
    log "Sending file: $FILE"

    # Build curl args safely (avoid line-continuation issues)
    curl_args=(
      -s
      -o /tmp/tg_resp.json
      -w "%{http_code}"
      -F "chat_id=${TELEGRAM_CHAT_ID}"
      -F "document=@${FILE}"
      --form-string "caption=${CAPTION}"
      -F "parse_mode=HTML"
      --form-string "reply_markup=${reply_markup}"
      "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendDocument"
    )

    if [ -n "${TELEGRAM_TOPIC_ID}" ]; then
      curl_args=( -s -o /tmp/tg_resp.json -w "%{http_code}"
        -F "chat_id=${TELEGRAM_CHAT_ID}"
        -F "message_thread_id=${TELEGRAM_TOPIC_ID}"
        -F "document=@${FILE}"
        --form-string "caption=${CAPTION}"
        -F "parse_mode=HTML"
        --form-string "reply_markup=${reply_markup}"
        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendDocument"
      )
    fi

    response="$(curl "${curl_args[@]}")"

    if [[ "$response" -eq 200 ]]; then
      log "Backup part sent successfully: $FILE"
    else
      log "Telegram HTTP status: $response"
      log "Telegram response body:"
      cat /tmp/tg_resp.json
      log "Failed to send ${REMARK} backup part: $FILE"
      exit 1
    fi
  done

  log "All backup parts sent successfully."
  date +%s > "$LAST_RUN_FILE"
else
  log "Backup file not found: $backup_name. Please check the server."
  exit 1
fi


# Final cleanup
shopt -s nullglob
for old in /root/*_"${REMARK}${TAG}"*; do
  rm -f -- "$old" 2>/dev/null || true
done
shopt -u nullglob
EOL

  # Replace placeholders in generated script
  sed -i \
    -e "s|__REMARK__|$(sed_escape "${REMARK}")|g" \
    -e "s|__PROJECT_NAME__|$(sed_escape "${PROJECT_NAME}")|g" \
    -e "s|__VERSION__|$(sed_escape "${VERSION}")|g" \
    -e "s|__TAG__|$(sed_escape "${TAG}")|g" \
    -e "s|__BACKUP_SUFFIX__|$(sed_escape "${BACKUP_SUFFIX}")|g" \
    -e "s|__SPLIT_SIZE__|$(sed_escape "${SPLIT_SIZE}")|g" \
    -e "s|__XUI_DB_DIR__|$(sed_escape "${XUI_DB_FOLDER_GLOBAL}")|g" \
    -e "s|__TIMEZONE__|$(sed_escape "${TIMEZONE}")|g" \
    -e "s|__TG_BOT__|$(sed_escape "${TELEGRAM_BOT_TOKEN}")|g" \
    -e "s|__TG_CHAT__|$(sed_escape "${TELEGRAM_CHAT_ID}")|g" \
    -e "s|__TG_TOPIC__|$(sed_escape "${TELEGRAM_TOPIC_ID}")|g" \
    -e "s|__INTERVAL_MINUTES__|$(sed_escape "${INTERVAL_MINUTES}")|g" \
    "$BACKUP_PATH"


  log "Running the backup script for the first time..."
  
  chmod +x "$BACKUP_PATH"
  success "Backup script created: $BACKUP_PATH"

  if bash "$BACKUP_PATH"; then
    success "First backup created and sent successfully."

    log "Setting up cron job..."
    # Ensure no duplicate cron entry for this script
    if (crontab -l 2>/dev/null | grep -vF "$BACKUP_PATH" || true; echo "$TIMER $BACKUP_PATH") | crontab -; then
      success "Cron job set up successfully. Backups will run automatically."
    else
      error "Failed to set up cron job. You can set it manually: $TIMER $BACKUP_PATH"
    fi

    success "🎉 ${PROJECT_NAME} is set up and running!"
    success "Backup script location: $BACKUP_PATH"
    success "Cron job: $TIMER"
    success "Owner: ${OWNER}"
    exit 0
  else
    error "Failed to run backup script. Please check the server."
  fi
}

#######################################
#                 main                #
#######################################

main() {
  clear
  print "${PROJECT_NAME} [${VERSION}] by ${OWNER}"
  print ""
  check_root
  menu
}

main
