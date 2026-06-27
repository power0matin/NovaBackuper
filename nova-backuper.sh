#!/usr/bin/env bash

# NovaBackuper - Interactive x-ui backup installer
# Author: @power0matin
# Version: v2.0.0

set -Eeuo pipefail

#######################################
#            Global constants         #
#######################################

readonly PROJECT_NAME="NovaBackuper"
readonly VERSION="v1.4.0"
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
input_secret() { read -s -p "$(echo -e "${COLORS[orange]}▶ $1${COLORS[reset]} ")" "$2"; echo; }
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
#        Encryption utilities         #
#######################################

# Detect available encryption tool: sets ENCRYPT_TOOL to "7z", "zip", or ""
detect_encrypt_tool() {
  if command -v 7z &>/dev/null; then
    echo "7z"
  elif command -v zip &>/dev/null; then
    echo "zip"
  else
    echo ""
  fi
}

# Validate that an encryption tool is available when encryption is requested
require_encrypt_tool() {
  local tool
  tool=$(detect_encrypt_tool)
  if [[ -z "$tool" ]]; then
    error "Encryption requested but neither 7z nor zip is available. Please install p7zip-full or zip."
  fi
  echo "$tool"
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
  local skipped=0
  local succeeded=0

  if compgen -G "/root/*${SCRIPT_SUFFIX}" > /dev/null; then
    for script in /root/*${SCRIPT_SUFFIX}; do
      log "Running backup script: $script"

      bash "$script"
      rc=$?

      if [ "$rc" -eq 0 ]; then
        succeeded=$((succeeded + 1))
      elif [ "$rc" -eq 75 ]; then
        skipped=$((skipped + 1))
        warn "Skipped (not due yet): $script"
      else
        failed=$((failed + 1))
        warn "Backup script failed (exit $rc): $script"
      fi
    done

    if [ "$failed" -gt 0 ]; then
      warn "Finished: ${succeeded} succeeded, ${skipped} skipped (not due), ${failed} failed."
    else
      if [ "$succeeded" -gt 0 ]; then
        success "Finished: ${succeeded} succeeded, ${skipped} skipped (not due), ${failed} failed."
      else
        warn "Finished: 0 succeeded, ${skipped} skipped (not due), 0 failed."
        warn "Nothing was sent because all scripts were not due yet."
      fi
    fi
  else
    warn "No backup scripts found in /root directory"
  fi

  confirm
}

#######################################
#          Edit backup (real editor)  #
#######################################

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

  local selected
  selected="${scripts[$((choice - 1))]}"

  # Show profile editor menu
  _profile_editor "$selected"
}

# Read a placeholder value from the generated script
_read_script_value() {
  local script="$1" placeholder="$2"
  grep -m1 "^${placeholder}=" "$script" 2>/dev/null | cut -d'"' -f2 || echo ""
}

# Replace a placeholder value in the generated script (in-place)
_set_script_value() {
  local script="$1" placeholder="$2" new_value="$3"
  sed -i "s|^${placeholder}=.*|${placeholder}=\"$(sed_escape "${new_value}")\"|" "$script"
}

_profile_editor() {
  local script="$1"

  while true; do
    clear
    print "[PROFILE EDITOR: $(basename "$script")]\n"

    # Read current values for display
    local cur_remark cur_interval cur_tz cur_tg_token cur_tg_chat cur_tg_topic
    local cur_dest cur_local_path cur_encrypt cur_enc_password
    cur_remark=$(_read_script_value "$script" "REMARK")
    cur_interval=$(_read_script_value "$script" "INTERVAL_MINUTES")
    cur_tz=$(_read_script_value "$script" "TIMEZONE")
    cur_tg_token=$(_read_script_value "$script" "TELEGRAM_BOT_TOKEN")
    cur_tg_chat=$(_read_script_value "$script" "TELEGRAM_CHAT_ID")
    cur_tg_topic=$(_read_script_value "$script" "TELEGRAM_TOPIC_ID")
    cur_dest=$(_read_script_value "$script" "DESTINATION")
    cur_local_path=$(_read_script_value "$script" "LOCAL_DEST_PATH")
    cur_encrypt=$(_read_script_value "$script" "ENCRYPT_ENABLED")

    print "Current profile: ${cur_remark}"
    print ""
    print "1) Change Remark          [${cur_remark}]"
    print "2) Change Interval        [${cur_interval} min]"
    print "3) Change Timezone        [${cur_tz}]"
    print "4) Change Telegram Settings"
    print "5) Change Backup Destination  [${cur_dest:-telegram}]"
    print "6) Change Encryption Settings [${cur_encrypt:-no}]"
    print "7) Save"
    print "8) Cancel"
    print ""

    local opt
    input "Choose an option:" opt

    case "$opt" in
      1)
        _edit_remark "$script" "$cur_remark"
        ;;
      2)
        _edit_interval "$script"
        ;;
      3)
        _edit_timezone "$script"
        ;;
      4)
        _edit_telegram "$script"
        ;;
      5)
        _edit_destination "$script"
        ;;
      6)
        _edit_encryption "$script"
        ;;
      7)
        success "Profile saved."
        sleep 1
        return
        ;;
      8)
        warn "Edit cancelled."
        sleep 1
        return
        ;;
      *)
        wrong "Invalid option."
        ;;
    esac
  done
}

_edit_remark() {
  local script="$1" old_remark="$2"

  while true; do
    input "New remark (current: ${old_remark}): " new_remark
    if ! [[ "$new_remark" =~ ^[a-zA-Z0-9_]+$ ]]; then
      wrong "Remark must contain only letters, numbers, or underscores."
    elif [ ${#new_remark} -lt 3 ]; then
      wrong "Remark must be at least 3 characters long."
    elif [ "$new_remark" = "$old_remark" ]; then
      warn "Same remark, nothing changed."
      break
    elif [ -e "/root/_${new_remark}${SCRIPT_SUFFIX}" ]; then
      wrong "File _${new_remark}${SCRIPT_SUFFIX} already exists. Choose a different remark."
    else
      # Rename the script file
      local new_script="/root/_${new_remark}${SCRIPT_SUFFIX}"
      _set_script_value "$script" "REMARK" "$new_remark"
      mv "$script" "$new_script"
      # Update cron entry
      crontab -l 2>/dev/null | sed "s|${script}|${new_script}|g" | crontab - || true
      success "Remark changed to: ${new_remark}. Script renamed."
      sleep 1
      return
    fi
  done
}

_edit_interval() {
  local script="$1"

  while true; do
    input "New interval in minutes (1-1440): " minutes
    if ! [[ "$minutes" =~ ^[0-9]+$ ]]; then
      wrong "Please enter a valid number."
    elif [ "$minutes" -lt 1 ] || [ "$minutes" -gt 1440 ]; then
      wrong "Number must be between 1 and 1440."
    else
      break
    fi
  done

  _set_script_value "$script" "INTERVAL_MINUTES" "$minutes"

  # Recalculate cron base frequency
  local cron_base
  if [ "$minutes" -lt 5 ]; then
    cron_base=1
  else
    cron_base=5
  fi
  local new_timer="*/${cron_base} * * * *"

  # Update cron: replace old entry for this script
  (crontab -l 2>/dev/null | grep -vF "$script" || true; echo "$new_timer $script") | crontab -

  success "Interval updated to ${minutes} min. Cron: ${new_timer}"
  sleep 1
}

_edit_timezone() {
  local script="$1"

  while true; do
    input "New timezone (e.g. Asia/Tehran, UTC): " new_tz
    if [[ -z "$new_tz" ]]; then
      wrong "Timezone cannot be empty."
    elif TZ="$new_tz" date >/dev/null 2>&1; then
      break
    else
      wrong "Invalid timezone. Example: Asia/Tehran, Europe/Berlin, America/New_York"
    fi
  done

  _set_script_value "$script" "TIMEZONE" "$new_tz"
  success "Timezone updated to: ${new_tz}"
  sleep 1
}

_edit_telegram() {
  local script="$1"

  print "\n[TELEGRAM SETTINGS]\n"

  # Token
  local new_token
  while true; do
    input "New bot token: " new_token
    if [[ -z "$new_token" ]]; then
      wrong "Bot token cannot be empty!"
    elif [[ ! "$new_token" =~ ^[0-9]+:[a-zA-Z0-9_-]{35,}$ ]]; then
      wrong "Invalid bot token format!"
    else
      break
    fi
  done

  # Chat ID
  local new_chat
  while true; do
    input "New chat ID: " new_chat
    if [[ -z "$new_chat" ]]; then
      wrong "Chat ID cannot be empty!"
    elif [[ ! "$new_chat" =~ ^-?[0-9]+$ ]]; then
      wrong "Invalid chat ID format!"
    else
      break
    fi
  done

  # Topic ID
  local new_topic
  while true; do
    input "New topic ID (Press Enter to skip): " new_topic
    if [[ -z "$new_topic" ]]; then
      new_topic=""
      break
    elif [[ ! "$new_topic" =~ ^[0-9]+$ ]]; then
      wrong "Invalid topic ID format! Must be a number."
    else
      break
    fi
  done

  # Validate
  log "Validating Telegram credentials..."
  local response
  if [[ -n "$new_topic" ]]; then
    response=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
      "https://api.telegram.org/bot${new_token}/sendMessage" \
      -d chat_id="$new_chat" \
      -d message_thread_id="$new_topic" \
      -d text="Hi from ${PROJECT_NAME} (test message).")
  else
    response=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
      "https://api.telegram.org/bot${new_token}/sendMessage" \
      -d chat_id="$new_chat" \
      -d text="Hi from ${PROJECT_NAME} (test message).")
  fi

  if [[ "$response" -ne 200 ]]; then
    wrong "Telegram validation failed (HTTP $response). Settings not saved."
    sleep 2
    return
  fi

  _set_script_value "$script" "TELEGRAM_BOT_TOKEN" "$new_token"
  _set_script_value "$script" "TELEGRAM_CHAT_ID"   "$new_chat"
  _set_script_value "$script" "TELEGRAM_TOPIC_ID"  "$new_topic"
  success "Telegram settings updated."
  sleep 1
}

_edit_destination() {
  local script="$1"

  print "\n[BACKUP DESTINATION]\n"
  print "1) Telegram"
  print "2) Local Folder"
  print "3) Telegram + Local Folder"
  print ""

  local dchoice
  while true; do
    input "Select destination (1-3): " dchoice
    case "$dchoice" in
      1) DESTINATION="telegram";  break ;;
      2) DESTINATION="local";     break ;;
      3) DESTINATION="both";      break ;;
      *) wrong "Invalid option." ;;
    esac
  done

  local local_path=""
  if [[ "$DESTINATION" == "local" || "$DESTINATION" == "both" ]]; then
    while true; do
      input "Destination path: " local_path
      if [[ -z "$local_path" ]]; then
        wrong "Path cannot be empty."
      elif [[ ! -d "$local_path" ]]; then
        wrong "Directory does not exist: $local_path"
      elif [[ ! -w "$local_path" ]]; then
        wrong "Directory is not writable: $local_path"
      else
        break
      fi
    done
  fi

  _set_script_value "$script" "DESTINATION"      "$DESTINATION"
  _set_script_value "$script" "LOCAL_DEST_PATH"  "$local_path"
  success "Destination updated to: ${DESTINATION}"
  sleep 1
}

_edit_encryption() {
  local script="$1"

  print "\n[ENCRYPTION SETTINGS]\n"
  print "1) No"
  print "2) Yes"
  print ""

  local echoice
  while true; do
    input "Enable backup encryption? (1-2): " echoice
    case "$echoice" in
      1) ENCRYPT_ENABLED="no";  break ;;
      2) ENCRYPT_ENABLED="yes"; break ;;
      *) wrong "Invalid option." ;;
    esac
  done

  local enc_password=""
  local enc_tool=""
  if [[ "$ENCRYPT_ENABLED" == "yes" ]]; then
    enc_tool=$(require_encrypt_tool)

    while true; do
      input_secret "Encryption password: " enc_password
      if [[ -z "$enc_password" ]]; then
        wrong "Password cannot be empty."
        continue
      fi
      local enc_confirm
      input_secret "Confirm password: " enc_confirm
      if [[ "$enc_password" != "$enc_confirm" ]]; then
        wrong "Passwords do not match. Try again."
      else
        break
      fi
    done
  fi

  _set_script_value "$script" "ENCRYPT_ENABLED"   "$ENCRYPT_ENABLED"
  _set_script_value "$script" "ENCRYPT_TOOL"      "$enc_tool"
  _set_script_value "$script" "ENCRYPT_PASSWORD"  "$enc_password"
  success "Encryption settings updated."
  sleep 1
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
  telegram_or_destination_progress
  ask_encryption
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

# Unified destination + telegram wizard
telegram_or_destination_progress() {
  clear
  print "[BACKUP DESTINATION]\n"
  print "1) Telegram"
  print "2) Local Folder"
  print "3) Telegram + Local Folder"
  print ""

  local dchoice
  while true; do
    input "Select destination (1-3): " dchoice
    case "$dchoice" in
      1) DESTINATION="telegram"; break ;;
      2) DESTINATION="local";    break ;;
      3) DESTINATION="both";     break ;;
      *) wrong "Invalid option." ;;
    esac
  done

  LOCAL_DEST_PATH=""
  if [[ "$DESTINATION" == "local" || "$DESTINATION" == "both" ]]; then
    while true; do
      input "Destination path: " LOCAL_DEST_PATH
      if [[ -z "$LOCAL_DEST_PATH" ]]; then
        wrong "Path cannot be empty."
      elif [[ ! -d "$LOCAL_DEST_PATH" ]]; then
        wrong "Directory does not exist: $LOCAL_DEST_PATH"
      elif [[ ! -w "$LOCAL_DEST_PATH" ]]; then
        wrong "Directory is not writable: $LOCAL_DEST_PATH"
      else
        break
      fi
    done
    success "Local destination: $LOCAL_DEST_PATH"
  fi

  if [[ "$DESTINATION" == "telegram" || "$DESTINATION" == "both" ]]; then
    telegram_progress
  else
    # No Telegram needed; set empty placeholders
    TELEGRAM_BOT_TOKEN=""
    TELEGRAM_CHAT_ID=""
    TELEGRAM_TOPIC_ID=""
    TIMEZONE="UTC"
    if command -v timedatectl >/dev/null 2>&1; then
      TIMEZONE=$(timedatectl show -p Timezone --value 2>/dev/null || echo "UTC")
    fi
    _ask_timezone
  fi

  sleep 1
}

_ask_timezone() {
  clear
  print "[TIMEZONE]\n"

  local default_tz="$TIMEZONE"
  while true; do
    input "Enter your timezone (e.g. Asia/Tehran) [default: ${default_tz}]: " USER_TZ
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

    # Ask for timezone
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
#        Encryption wizard            #
#######################################

ask_encryption() {
  clear
  print "[ENCRYPTION]\n"
  print "Enable backup encryption?\n"
  print "1) No"
  print "2) Yes"
  print ""

  local echoice
  while true; do
    input "Select option (1-2): " echoice
    case "$echoice" in
      1) ENCRYPT_ENABLED="no";  break ;;
      2) ENCRYPT_ENABLED="yes"; break ;;
      *) wrong "Invalid option." ;;
    esac
  done

  ENCRYPT_TOOL=""
  ENCRYPT_PASSWORD=""

  if [[ "$ENCRYPT_ENABLED" == "yes" ]]; then
    ENCRYPT_TOOL=$(require_encrypt_tool)
    log "Encryption tool: ${ENCRYPT_TOOL}"

    while true; do
      input_secret "Encryption password: " ENCRYPT_PASSWORD
      if [[ -z "$ENCRYPT_PASSWORD" ]]; then
        wrong "Password cannot be empty."
        continue
      fi
      local enc_confirm
      input_secret "Confirm password: " enc_confirm
      if [[ "$ENCRYPT_PASSWORD" != "$enc_confirm" ]]; then
        wrong "Passwords do not match. Try again."
      else
        break
      fi
    done

    success "Encryption enabled using ${ENCRYPT_TOOL} (AES-256)."
  else
    success "Encryption disabled."
  fi
  sleep 1
}

#######################################
#           Script generator          #
#######################################

# Escape replacement text for sed (handles &, | and backslashes safely)
sed_escape() {
  printf '%s' "$1" | sed -e 's/[\\/&|]/\\&/g'
}

generate_script() {
  clear
  local BACKUP_PATH="/root/_${REMARK}${SCRIPT_SUFFIX}"

  log "Generating backup script: $BACKUP_PATH"

  cat <<'EOL' > "$BACKUP_PATH"
#!/usr/bin/env bash
set -Eeuo pipefail

# Auto-generated by NovaBackuper
# Remark: __REMARK__

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

DESTINATION="__DESTINATION__"
LOCAL_DEST_PATH="__LOCAL_DEST_PATH__"

ENCRYPT_ENABLED="__ENCRYPT_ENABLED__"
ENCRYPT_TOOL="__ENCRYPT_TOOL__"
ENCRYPT_PASSWORD="__ENCRYPT_PASSWORD__"

INTERVAL_MINUTES="__INTERVAL_MINUTES__"
FORCE_RUN="${FORCE_RUN:-0}"

backup_base="/root/${timestamp}_${REMARK}${TAG}"
backup_name="/root/${timestamp}_${REMARK}${BACKUP_SUFFIX}"

log()   { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

STATE_DIR="/var/lib/novabackuper"
LAST_RUN_FILE="${STATE_DIR}/${REMARK}.last_run"
LOCK_DIR="${STATE_DIR}/${REMARK}.lockdir"

mkdir -p "$STATE_DIR"

should_run_now() {
  local now last
  now=$(date +%s)

  if [ "${FORCE_RUN}" = "1" ]; then
    log "Force run enabled: bypassing interval gate."
    return 0
  fi

  if [ -f "$LAST_RUN_FILE" ]; then
    last=$(cat "$LAST_RUN_FILE" 2>/dev/null || echo 0)
    if [[ "$last" =~ ^[0-9]+$ ]]; then
      if (( now - last < INTERVAL_MINUTES * 60 )); then
        log "Skip: not due yet (interval ${INTERVAL_MINUTES}m)."
        return 75   # special code: not due
      fi
    fi
  fi

  return 0
}

acquire_lock() {
  if mkdir "$LOCK_DIR" 2>/dev/null; then
    trap 'rm -rf "$LOCK_DIR" 2>/dev/null || true' EXIT
    return 0
  fi
  log "Skip: another backup run is in progress."
  return 1
}

acquire_lock || exit 0

if ! should_run_now; then
  rc=$?
  exit "$rc"
fi

# Build caption dynamically at runtime
CAPTION="$(cat <<EOF
<b>🛡 ${PROJECT_NAME}</b>

🕒 <b>Time:</b> $(TZ="${TIMEZONE}" date '+%Y-%m-%d %H:%M:%S %:z') (<code>${TIMEZONE}</code>)
🖥 <b>Host:</b> <code>$(hostname)</code> [<code>${ip}</code>]
📦 <b>Backup ID:</b> <code>${timestamp}_${REMARK}</code>
📚 <b>Scope:</b> x-ui database (<code>x-ui.db</code> / <code>x-ui.db-wal</code> / <code>x-ui.db-shm</code>)
EOF
)"

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

log "Creating backup archive: ${backup_name}"
log "Including files:"
printf '  - %s\n' "${db_files[@]}"

# ---- Create archive (with optional encryption) ----
if [[ "${ENCRYPT_ENABLED}" == "yes" ]]; then
  if [[ "${ENCRYPT_TOOL}" == "7z" ]]; then
    # 7z produces a single encrypted archive; split afterwards if needed
    local_archive="/root/${timestamp}_${REMARK}${TAG}enc.7z"
    if ! 7z a -mhe=on -mx=9 "-p${ENCRYPT_PASSWORD}" "$local_archive" "${db_files[@]}"; then
      log "Failed to create encrypted 7z archive. Aborting."
      exit 1
    fi
    # For Telegram multi-part support, split with zip-style naming using split
    # We use the 7z archive directly (single file, typically small for x-ui db)
    backup_files=( "$local_archive" )
  else
    # zip -e fallback (password-protected zip)
    enc_zip="/root/${timestamp}_${REMARK}${TAG}enc.zip"
    if ! zip -9 -e --password "${ENCRYPT_PASSWORD}" "$enc_zip" "${db_files[@]}"; then
      log "Failed to create encrypted zip archive. Aborting."
      exit 1
    fi
    backup_files=( "$enc_zip" )
  fi
else
  # Plain zip with split support
  if ! zip -9 -r -s "${SPLIT_SIZE}" "$backup_name" "${db_files[@]}"; then
    log "Failed to compress ${REMARK} files. Please check the server."
    exit 1
  fi
  shopt -s nullglob
  backup_files=( "${backup_base}"* )
  shopt -u nullglob
fi

if [ "${#backup_files[@]}" -eq 0 ]; then
  log "Backup file not found after creation. Aborting."
  exit 1
fi

# ---- Deliver backup ----

send_to_telegram() {
  local FILE="$1"
  log "Sending file to Telegram: $FILE"

  local curl_args=(
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
    curl_args=(
      -s
      -o /tmp/tg_resp.json
      -w "%{http_code}"
      -F "chat_id=${TELEGRAM_CHAT_ID}"
      -F "message_thread_id=${TELEGRAM_TOPIC_ID}"
      -F "document=@${FILE}"
      --form-string "caption=${CAPTION}"
      -F "parse_mode=HTML"
      --form-string "reply_markup=${reply_markup}"
      "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendDocument"
    )
  fi

  local response
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
}

copy_to_local() {
  local FILE="$1"
  if [[ -z "${LOCAL_DEST_PATH}" ]]; then
    log "Local destination path not set. Aborting local copy."
    exit 1
  fi
  log "Copying file to local destination: ${LOCAL_DEST_PATH}"
  if ! cp "$FILE" "${LOCAL_DEST_PATH}/"; then
    log "Failed to copy backup to ${LOCAL_DEST_PATH}. Aborting."
    exit 1
  fi
  log "File copied: ${LOCAL_DEST_PATH}/$(basename "$FILE")"
}

for bfile in "${backup_files[@]}"; do
  case "${DESTINATION}" in
    telegram)
      send_to_telegram "$bfile"
      ;;
    local)
      copy_to_local "$bfile"
      ;;
    both)
      send_to_telegram "$bfile"
      copy_to_local "$bfile"
      ;;
    *)
      log "Unknown destination '${DESTINATION}'. Defaulting to Telegram."
      send_to_telegram "$bfile"
      ;;
  esac
done

log "All backup parts delivered successfully."
date +%s > "$LAST_RUN_FILE"

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
    -e "s|__DESTINATION__|$(sed_escape "${DESTINATION}")|g" \
    -e "s|__LOCAL_DEST_PATH__|$(sed_escape "${LOCAL_DEST_PATH}")|g" \
    -e "s|__ENCRYPT_ENABLED__|$(sed_escape "${ENCRYPT_ENABLED}")|g" \
    -e "s|__ENCRYPT_TOOL__|$(sed_escape "${ENCRYPT_TOOL}")|g" \
    -e "s|__ENCRYPT_PASSWORD__|$(sed_escape "${ENCRYPT_PASSWORD}")|g" \
    -e "s|__INTERVAL_MINUTES__|$(sed_escape "${INTERVAL_MINUTES}")|g" \
    "$BACKUP_PATH"

  chmod +x "$BACKUP_PATH"
  success "Backup script created: $BACKUP_PATH"

  log "Running the backup script for the first time..."

  # Force first run to ensure an initial backup is created and sent immediately
  if FORCE_RUN=1 bash "$BACKUP_PATH"; then
    success "First backup created and sent successfully."
  else
    rc=$?
    if [ "$rc" -eq 75 ]; then
      warn "First run skipped: not due yet by interval gate. You can force a manual run with: FORCE_RUN=1 bash $BACKUP_PATH"
    else
      error "Failed to run backup script (exit $rc). Please check the server."
    fi
  fi

  log "Setting up cron job..."
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
}

#######################################
#            Silent / CLI mode        #
#######################################

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --help                     Show this help message
  --silent                   Run in silent (non-interactive) mode; must be
                             combined with an action flag
  --install                  Install a new backup profile (silent mode)
  --edit REMARK              Edit an existing profile by remark (silent mode)
  --remove                   Remove all NovaBackuper scripts and cron jobs
  --run                      Run all backup scripts immediately
  --update                   Update NovaBackuper to the latest version

Silent --install flags:
  --remark         NAME      Profile remark (letters/numbers/underscores, >=3 chars)
  --interval       MINUTES   Backup interval in minutes (1-1440)
  --timezone       TZ        IANA timezone (e.g. Asia/Tehran)
  --destination    DEST      telegram | local | both
  --local-path     PATH      Local destination path (required if destination=local/both)
  --telegram-token TOKEN     Telegram bot token
  --telegram-chat-id ID      Telegram chat ID
  --telegram-topic-id ID     Telegram topic/thread ID (optional)
  --encrypt        yes|no    Enable encryption
  --password       PASS      Encryption password (required if --encrypt yes)

Silent --edit REMARK flags (all optional; only supplied fields are changed):
  --interval, --timezone, --destination, --local-path,
  --telegram-token, --telegram-chat-id, --telegram-topic-id,
  --encrypt, --password

Examples:
  $(basename "$0") --silent --install \\
      --remark main --interval 60 \\
      --telegram-token 123:ABC --telegram-chat-id -100123 \\
      --timezone Asia/Tehran \\
      --destination telegram \\
      --encrypt no

  $(basename "$0") --silent --edit main --interval 30
  $(basename "$0") --silent --remove
  $(basename "$0") --silent --run
EOF
}

# Validate a Telegram connection silently (no interactive prompt)
_silent_validate_telegram() {
  local token="$1" chat="$2" topic="${3:-}"
  local response
  if [[ -n "$topic" ]]; then
    response=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
      "https://api.telegram.org/bot${token}/sendMessage" \
      -d chat_id="$chat" \
      -d message_thread_id="$topic" \
      -d text="Hi from ${PROJECT_NAME} (test message).")
  else
    response=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
      "https://api.telegram.org/bot${token}/sendMessage" \
      -d chat_id="$chat" \
      -d text="Hi from ${PROJECT_NAME} (test message).")
  fi
  echo "$response"
}

# Validate an IANA timezone string
_validate_tz() {
  TZ="$1" date >/dev/null 2>&1
}

# Validate a local destination path
_validate_local_path() {
  [[ -d "$1" && -w "$1" ]]
}

silent_install() {
  # All required fields must already be in global vars set by parse_args
  local err=0

  # --- Remark ---
  if [[ -z "${REMARK:-}" ]]; then
    echo "[ERROR] --remark is required." >&2; err=1
  elif ! [[ "$REMARK" =~ ^[a-zA-Z0-9_]+$ ]] || [ ${#REMARK} -lt 3 ]; then
    echo "[ERROR] --remark must be alphanumeric/underscore and at least 3 chars." >&2; err=1
  elif [ -e "/root/_${REMARK}${SCRIPT_SUFFIX}" ]; then
    echo "[ERROR] Profile '${REMARK}' already exists." >&2; err=1
  fi

  # --- Interval ---
  if [[ -z "${INTERVAL_MINUTES:-}" ]]; then
    echo "[ERROR] --interval is required." >&2; err=1
  elif ! [[ "$INTERVAL_MINUTES" =~ ^[0-9]+$ ]] || [ "$INTERVAL_MINUTES" -lt 1 ] || [ "$INTERVAL_MINUTES" -gt 1440 ]; then
    echo "[ERROR] --interval must be a number between 1 and 1440." >&2; err=1
  fi

  # --- Timezone ---
  if [[ -z "${TIMEZONE:-}" ]]; then
    echo "[ERROR] --timezone is required." >&2; err=1
  elif ! _validate_tz "${TIMEZONE}"; then
    echo "[ERROR] Invalid timezone: ${TIMEZONE}" >&2; err=1
  fi

  # --- Destination ---
  case "${DESTINATION:-}" in
    telegram|local|both) ;;
    "") echo "[ERROR] --destination is required (telegram|local|both)." >&2; err=1 ;;
    *)  echo "[ERROR] Invalid destination '${DESTINATION}'. Use: telegram|local|both." >&2; err=1 ;;
  esac

  # --- Local path ---
  if [[ "${DESTINATION:-}" == "local" || "${DESTINATION:-}" == "both" ]]; then
    if [[ -z "${LOCAL_DEST_PATH:-}" ]]; then
      echo "[ERROR] --local-path is required when destination is local/both." >&2; err=1
    elif ! _validate_local_path "${LOCAL_DEST_PATH}"; then
      echo "[ERROR] Local path '${LOCAL_DEST_PATH}' does not exist or is not writable." >&2; err=1
    fi
  fi

  # --- Telegram ---
  if [[ "${DESTINATION:-}" == "telegram" || "${DESTINATION:-}" == "both" ]]; then
    if [[ -z "${TELEGRAM_BOT_TOKEN:-}" ]]; then
      echo "[ERROR] --telegram-token is required for Telegram destination." >&2; err=1
    elif [[ ! "$TELEGRAM_BOT_TOKEN" =~ ^[0-9]+:[a-zA-Z0-9_-]{35,}$ ]]; then
      echo "[ERROR] Invalid bot token format." >&2; err=1
    fi
    if [[ -z "${TELEGRAM_CHAT_ID:-}" ]]; then
      echo "[ERROR] --telegram-chat-id is required for Telegram destination." >&2; err=1
    elif [[ ! "$TELEGRAM_CHAT_ID" =~ ^-?[0-9]+$ ]]; then
      echo "[ERROR] Invalid chat ID format." >&2; err=1
    fi
    if [[ -n "${TELEGRAM_TOPIC_ID:-}" ]] && [[ ! "$TELEGRAM_TOPIC_ID" =~ ^[0-9]+$ ]]; then
      echo "[ERROR] Invalid topic ID format (must be a number)." >&2; err=1
    fi
  fi

  # --- Encryption ---
  case "${ENCRYPT_ENABLED:-no}" in
    yes|no) ;;
    *) echo "[ERROR] --encrypt must be yes or no." >&2; err=1 ;;
  esac

  if [[ "${ENCRYPT_ENABLED:-no}" == "yes" ]]; then
    if [[ -z "${ENCRYPT_PASSWORD:-}" ]]; then
      echo "[ERROR] --password is required when --encrypt yes." >&2; err=1
    fi
    ENCRYPT_TOOL=$(detect_encrypt_tool)
    if [[ -z "$ENCRYPT_TOOL" ]]; then
      echo "[ERROR] Encryption requested but neither 7z nor zip is available." >&2; err=1
    fi
  else
    ENCRYPT_TOOL=""
    ENCRYPT_PASSWORD=""
  fi

  [ "$err" -ne 0 ] && exit 1

  # --- Telegram validation (network) ---
  if [[ "${DESTINATION}" == "telegram" || "${DESTINATION}" == "both" ]]; then
    echo "[INFO] Validating Telegram credentials..."
    local tg_resp
    tg_resp=$(_silent_validate_telegram "${TELEGRAM_BOT_TOKEN}" "${TELEGRAM_CHAT_ID}" "${TELEGRAM_TOPIC_ID:-}")
    if [[ "$tg_resp" -ne 200 ]]; then
      echo "[ERROR] Telegram validation failed (HTTP $tg_resp). Check token/chat-id/topic-id." >&2
      exit 1
    fi
    echo "[INFO] Telegram credentials valid."
  fi

  # --- x-ui check ---
  local XUI_DB_FOLDER="/etc/x-ui"
  if [ ! -d "$XUI_DB_FOLDER" ] || [ ! -f "${XUI_DB_FOLDER}/x-ui.db" ]; then
    echo "[ERROR] x-ui not found at ${XUI_DB_FOLDER}." >&2; exit 1
  fi
  XUI_DB_FOLDER_GLOBAL="$XUI_DB_FOLDER"

  # --- Cron timer ---
  if [ "$INTERVAL_MINUTES" -lt 5 ]; then
    CRON_BASE_MINUTES=1
  else
    CRON_BASE_MINUTES=5
  fi
  TIMER="*/${CRON_BASE_MINUTES} * * * *"

  # --- Generate ---
  TELEGRAM_TOPIC_ID="${TELEGRAM_TOPIC_ID:-}"
  LOCAL_DEST_PATH="${LOCAL_DEST_PATH:-}"
  generate_script
}

silent_edit() {
  local edit_remark="${1:-}"
  if [[ -z "$edit_remark" ]]; then
    echo "[ERROR] --edit requires a REMARK argument." >&2; exit 1
  fi

  local script="/root/_${edit_remark}${SCRIPT_SUFFIX}"
  if [[ ! -f "$script" ]]; then
    echo "[ERROR] Profile '${edit_remark}' not found at ${script}." >&2; exit 1
  fi

  local changed=0

  # Interval
  if [[ -n "${INTERVAL_MINUTES:-}" ]]; then
    if ! [[ "$INTERVAL_MINUTES" =~ ^[0-9]+$ ]] || [ "$INTERVAL_MINUTES" -lt 1 ] || [ "$INTERVAL_MINUTES" -gt 1440 ]; then
      echo "[ERROR] --interval must be 1-1440." >&2; exit 1
    fi
    _set_script_value "$script" "INTERVAL_MINUTES" "$INTERVAL_MINUTES"
    local cron_base
    if [ "$INTERVAL_MINUTES" -lt 5 ]; then cron_base=1; else cron_base=5; fi
    local new_timer="*/${cron_base} * * * *"
    (crontab -l 2>/dev/null | grep -vF "$script" || true; echo "$new_timer $script") | crontab -
    echo "[INFO] Interval updated to ${INTERVAL_MINUTES} min."
    changed=1
  fi

  # Timezone
  if [[ -n "${TIMEZONE:-}" ]]; then
    if ! _validate_tz "$TIMEZONE"; then
      echo "[ERROR] Invalid timezone: ${TIMEZONE}" >&2; exit 1
    fi
    _set_script_value "$script" "TIMEZONE" "$TIMEZONE"
    echo "[INFO] Timezone updated to ${TIMEZONE}."
    changed=1
  fi

  # Destination
  if [[ -n "${DESTINATION:-}" ]]; then
    case "$DESTINATION" in
      telegram|local|both) ;;
      *) echo "[ERROR] Invalid destination '${DESTINATION}'." >&2; exit 1 ;;
    esac
    _set_script_value "$script" "DESTINATION" "$DESTINATION"
    echo "[INFO] Destination updated to ${DESTINATION}."
    changed=1
  fi

  # Local path
  if [[ -n "${LOCAL_DEST_PATH:-}" ]]; then
    if ! _validate_local_path "$LOCAL_DEST_PATH"; then
      echo "[ERROR] Local path '${LOCAL_DEST_PATH}' does not exist or is not writable." >&2; exit 1
    fi
    _set_script_value "$script" "LOCAL_DEST_PATH" "$LOCAL_DEST_PATH"
    echo "[INFO] Local path updated to ${LOCAL_DEST_PATH}."
    changed=1
  fi

  # Telegram token
  if [[ -n "${TELEGRAM_BOT_TOKEN:-}" ]]; then
    if [[ ! "$TELEGRAM_BOT_TOKEN" =~ ^[0-9]+:[a-zA-Z0-9_-]{35,}$ ]]; then
      echo "[ERROR] Invalid bot token format." >&2; exit 1
    fi
    _set_script_value "$script" "TELEGRAM_BOT_TOKEN" "$TELEGRAM_BOT_TOKEN"
    echo "[INFO] Telegram bot token updated."
    changed=1
  fi

  # Telegram chat ID
  if [[ -n "${TELEGRAM_CHAT_ID:-}" ]]; then
    if [[ ! "$TELEGRAM_CHAT_ID" =~ ^-?[0-9]+$ ]]; then
      echo "[ERROR] Invalid chat ID format." >&2; exit 1
    fi
    _set_script_value "$script" "TELEGRAM_CHAT_ID" "$TELEGRAM_CHAT_ID"
    echo "[INFO] Telegram chat ID updated."
    changed=1
  fi

  # Telegram topic ID
  if [[ -n "${TELEGRAM_TOPIC_ID:-}" ]]; then
    if [[ ! "$TELEGRAM_TOPIC_ID" =~ ^[0-9]+$ ]]; then
      echo "[ERROR] Invalid topic ID format (must be a number)." >&2; exit 1
    fi
    _set_script_value "$script" "TELEGRAM_TOPIC_ID" "$TELEGRAM_TOPIC_ID"
    echo "[INFO] Telegram topic ID updated."
    changed=1
  fi

  # Encryption
  if [[ -n "${ENCRYPT_ENABLED:-}" ]]; then
    case "$ENCRYPT_ENABLED" in
      yes|no) ;;
      *) echo "[ERROR] --encrypt must be yes or no." >&2; exit 1 ;;
    esac
    local enc_tool="" enc_pass=""
    if [[ "$ENCRYPT_ENABLED" == "yes" ]]; then
      enc_tool=$(detect_encrypt_tool)
      if [[ -z "$enc_tool" ]]; then
        echo "[ERROR] Neither 7z nor zip available for encryption." >&2; exit 1
      fi
      if [[ -z "${ENCRYPT_PASSWORD:-}" ]]; then
        echo "[ERROR] --password is required when --encrypt yes." >&2; exit 1
      fi
      enc_pass="${ENCRYPT_PASSWORD}"
    fi
    _set_script_value "$script" "ENCRYPT_ENABLED"  "$ENCRYPT_ENABLED"
    _set_script_value "$script" "ENCRYPT_TOOL"     "$enc_tool"
    _set_script_value "$script" "ENCRYPT_PASSWORD" "$enc_pass"
    echo "[INFO] Encryption settings updated."
    changed=1
  fi

  if [[ "$changed" -eq 0 ]]; then
    echo "[WARN] No changes specified. Use --help for available flags."
  else
    echo "[SUCCESS] Profile '${edit_remark}' updated."
  fi
}

parse_args() {
  # Defaults
  SILENT_MODE=0
  CLI_ACTION=""
  CLI_EDIT_REMARK=""
  REMARK="${REMARK:-}"
  INTERVAL_MINUTES="${INTERVAL_MINUTES:-}"
  TIMEZONE="${TIMEZONE:-}"
  DESTINATION="${DESTINATION:-}"
  LOCAL_DEST_PATH="${LOCAL_DEST_PATH:-}"
  TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
  TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"
  TELEGRAM_TOPIC_ID="${TELEGRAM_TOPIC_ID:-}"
  ENCRYPT_ENABLED="${ENCRYPT_ENABLED:-no}"
  ENCRYPT_PASSWORD="${ENCRYPT_PASSWORD:-}"
  ENCRYPT_TOOL=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        usage
        exit 0
        ;;
      --silent)
        SILENT_MODE=1
        shift
        ;;
      --install)
        CLI_ACTION="install"
        shift
        ;;
      --edit)
        CLI_ACTION="edit"
        CLI_EDIT_REMARK="${2:-}"
        shift; [[ $# -gt 0 ]] && shift || true
        ;;
      --remove)
        CLI_ACTION="remove"
        shift
        ;;
      --run)
        CLI_ACTION="run"
        shift
        ;;
      --update)
        CLI_ACTION="update"
        shift
        ;;
      --remark)
        REMARK="${2:-}"; shift 2
        ;;
      --interval)
        INTERVAL_MINUTES="${2:-}"; shift 2
        ;;
      --timezone)
        TIMEZONE="${2:-}"; shift 2
        ;;
      --destination)
        DESTINATION="${2:-}"; shift 2
        ;;
      --local-path)
        LOCAL_DEST_PATH="${2:-}"; shift 2
        ;;
      --telegram-token)
        TELEGRAM_BOT_TOKEN="${2:-}"; shift 2
        ;;
      --telegram-chat-id)
        TELEGRAM_CHAT_ID="${2:-}"; shift 2
        ;;
      --telegram-topic-id)
        TELEGRAM_TOPIC_ID="${2:-}"; shift 2
        ;;
      --encrypt)
        ENCRYPT_ENABLED="${2:-no}"; shift 2
        ;;
      --password)
        ENCRYPT_PASSWORD="${2:-}"; shift 2
        ;;
      *)
        echo "[ERROR] Unknown argument: $1" >&2
        usage
        exit 1
        ;;
    esac
  done
}

run_cli() {
  check_root

  case "$CLI_ACTION" in
    install)
      install_dependencies
      silent_install
      ;;
    edit)
      silent_edit "$CLI_EDIT_REMARK"
      ;;
    remove)
      cleanup_backups
      ;;
    run)
      run_all_backup_scripts
      ;;
    update)
      update_novabackuper
      ;;
    "")
      echo "[ERROR] --silent requires an action: --install, --edit, --remove, --run, or --update." >&2
      usage
      exit 1
      ;;
    *)
      echo "[ERROR] Unknown action: ${CLI_ACTION}" >&2
      usage
      exit 1
      ;;
  esac
}

#######################################
#                 main                #
#######################################

main() {
  parse_args "$@"

  if [[ "$SILENT_MODE" -eq 1 || -n "$CLI_ACTION" ]]; then
    run_cli
  else
    clear
    print "${PROJECT_NAME} [${VERSION}] by ${OWNER}"
    print ""
    check_root
    menu
  fi
}

main "$@"