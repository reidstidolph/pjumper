#!/usr/bin/env bash

VERSION="1.0.1"
CONFIG_DIR="/etc/128t-support"
CONFIG="$CONFIG_DIR/128t-support-vars"
SERVER_FINGERPRINT="$CONFIG_DIR/support-fingerprint"
LOCAL_ID="$CONFIG_DIR/support-id"
LOCAL_PUBKEY="$CONFIG_DIR/support-id.pub"
SERVICE_FILE="/usr/lib/systemd/system/128T-support.service"
SUPPORT_HOST="20.25.240.168"
SUPPORT_HOST_PORT="443"
SUPPORT_USER="t128"

# Print cool 128T header
function print_header(){
    PRI_COLOR=""
    SEC_COLOR=""
    TER_COLOR=""
    RESET="\e[0m"
    RANDOMNUM=$(( $RANDOM % 3 + 1 ))

    function print128() {
        function print {
            printf $2
            for i in $(seq 1 $1)
            do
                printf " "
            done
            printf "$RESET"
        }

    }

    if [[ "$RANDOMNUM" -eq "1" ]]; then
        PRI_COLOR="\e[1;48;5;039;38;5;237m" #Blue with grey text
        SEC_COLOR="\e[48;5;15m" #White
    fi

    if [[ "$RANDOMNUM" -eq "2" ]]; then
        PRI_COLOR="\e[1;48;5;15;38;5;237m" #White with grey text
        SEC_COLOR="\e[48;5;039m" #Blue
    fi

    if [[ "$RANDOMNUM" -eq "3" ]]; then
        PRI_COLOR="\e[1;48;5;237;38;5;15m" #Gray with white text
        SEC_COLOR="\e[48;5;039m" #Blue
    fi

    printf "$PRI_COLOR                                                                   $RESET\n"
    printf "$PRI_COLOR                                                                   $RESET\n"
    printf "$PRI_COLOR                    $SEC_COLOR           $PRI_COLOR   $SEC_COLOR    $PRI_COLOR    $SEC_COLOR    $PRI_COLOR                     $RESET\n"
    printf "$PRI_COLOR                    $SEC_COLOR           $PRI_COLOR   $SEC_COLOR    $PRI_COLOR    $SEC_COLOR    $PRI_COLOR                     $RESET\n"
    printf "$PRI_COLOR                    $SEC_COLOR    $PRI_COLOR          $SEC_COLOR    $PRI_COLOR                             $RESET\n"
    printf "$PRI_COLOR                    $SEC_COLOR    $PRI_COLOR          $SEC_COLOR    $PRI_COLOR                             $RESET\n"
    printf "$PRI_COLOR                    $SEC_COLOR    $PRI_COLOR   $SEC_COLOR           $PRI_COLOR    $SEC_COLOR    $PRI_COLOR                     $RESET\n"
    printf "$PRI_COLOR                    $SEC_COLOR    $PRI_COLOR   $SEC_COLOR           $PRI_COLOR    $SEC_COLOR    $PRI_COLOR                     $RESET\n"
    printf "$PRI_COLOR                                                                   $RESET\n"
    printf "$PRI_COLOR                                                                   $RESET\n"
    printf "$PRI_COLOR                 128T Remote Support Tool v$VERSION                   $RESET\n"
    printf "$PRI_COLOR                                                                   $RESET\n"

}

# Print help text
function show_help(){

    echo "Usage: '128t-support <command>'"
    echo "Commands:"
    echo "   start     : Start 128t-support"
    echo "   status    : View status of 128t-support"
    echo "   stop      : Stop 128t-support"
    echo "   enable    : Enable 128t-support run on boot"
    echo "   disable   : Disable 128t-support run on boot"
    echo "   init      : Reinitialize 128t-support"
    echo "   pin       : Set host pin code (provided by 128 Technology support)"
    echo "   key       : Show 128t-support client public key"
    echo ""
}

# Sudo check
function sudo_check(){

  if (( $EUID != 0 )); then
    echo ""
    echo "ERROR"
    echo ""
    echo "Unable to run with elevated privilages."
    echo "Please as root or use 'sudo'."
    echo ""
    echo "...quitting."
    exit 1
  fi

}

# Generate local identity and public key
function generate_local_keys(){

  ssh-keygen -O clear -O permit-port-forwarding -b 4096 -f $LOCAL_ID -N ''

}

# Print public key
function print_public_key(){
  echo "======BEGIN PUBLIC KEY======"
  cat $LOCAL_PUBKEY
  echo "=======END PUBLIC KEY======="
}

# Set up the systemd service
function set_service(){

  cat > $SERVICE_FILE << EOF
[Unit]
Description=remote support from 128 Technology

[Service]
TimeoutStartSec=0
EnvironmentFile=$CONFIG
ExecStart=/usr/bin/ssh -o ServerAliveInterval=60 -o ExitOnForwardFailure=yes -o ConnectTimeout=10 -o UserKnownHostsFile=$SERVER_FINGERPRINT -i $LOCAL_ID -N -R 127.0.0.1:\${SUPPORT_HOST_PIN}:127.0.0.1:22 -p \$SUPPORT_HOST_PORT \${SUPPORT_USER}@\${SUPPORT_HOST}
Restart=always
RestartSec=60

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
}

function set_config(){
  echo "SUPPORT_HOST=\"$SUPPORT_HOST\"" > $CONFIG
  echo "SUPPORT_HOST_PORT=\"$SUPPORT_HOST_PORT\"" >> $CONFIG
  echo "SUPPORT_USER=\"$SUPPORT_USER\"" >> $CONFIG
}

function service_ctl(){
  systemctl $1 128T-support.service
}

function init(){

  echo "Creating config..."
  mkdir $CONFIG_DIR
  set_config
  echo "...done."
  echo "Setting up a 128t-support identity..."
  cat > $SERVER_FINGERPRINT << 'EOF'
[20.25.240.168]:443 ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBBfbaQz073zvumMvqQQcihV/jTx5blCGL2eiFBfhD4HagT1aPozAx/5zQJZq6vxq8kSAZFfVnqJUt8gwqCrTfao=
EOF

  generate_local_keys
  echo "...done."
  echo "Setting up system service..."
  set_service
  echo "...done."
  echo ""
  echo "Setup is complete."
  echo ""
  echo "Send the following key text to your 128 Technology support representative:"
  echo ""
  print_public_key
  echo ""
  echo "This key will authorize this host to connect to 128 Technology support."
  echo "To display this again at any time, just run '128t-support key'"
  echo ""
}

function set_pin(){

  echo "Please enter pin number:"
  read pin_user_input
  if [[ "$pin_user_input" -gt 1024 && "$pin_user_input" -lt 65535 ]] ; then
    echo "Pin set."
    # reset config
    set_config
    echo "SUPPORT_HOST_PIN=\"$pin_user_input\"" >> $CONFIG
  else
    echo ""
    echo "Invalid Pin."
    echo "Please enter the pin number provided by your 128 Technology support representative."
    echo ""
    set_pin
  fi
}

function check_pin(){

  grep -Eq 'SUPPORT_HOST_PIN="[0-9]+"' "$CONFIG"
  if [ $? -ne 0 ] ; then
      return 1
  else
      return 0
  fi
}

function nuke(){
  echo ""
  echo "Removing 128t-support..."
  echo ""
  echo "Stopping service..."
  echo "...done."
  service_ctl stop
  echo "Cleaning up service file..."
  rm -f $SERVICE_FILE
  systemctl daemon-reload
  echo "...done."
  echo "Deleting local identity..."
  rm -f $LOCAL_ID
  rm -f $LOCAL_PUBKEY
  echo "...done."
  echo "Deleting local config..."
  rm -f $CONFIG
  echo "...done."
  echo "Cleaning up..."
  rm -f $CONFIG_DIR/*
  rmdir $CONFIG_DIR
  echo "...done."
  echo ""
  echo "128t-support removed."
  echo ""
  exit 0
}

function verify_install(){
  if [[ ! -d $CONFIG_DIR || ! -f $CONFIG || ! -f $LOCAL_ID || ! -f $LOCAL_PUBKEY || ! -f $SERVICE_FILE ]]; then
    # missing files and directories required for 128t-support
    return 1
  else
    # 128t-support appears to be set up properly
    return 0
  fi
}


# Function for prompting the user with a yes/no question
function user_prompt(){
  echo ""
  echo "$1"
  read user_input
  if [[ $user_input = "y" ]]; then
    return 0
  elif [[ $user_input = "n" ]]; then
    return 1
  else
    echo "Please enter 'y' for yes, or 'n' for no."
    user_prompt "$1"
  fi
}

# Function for prompting user to start/enable 128t-support
function start_enable_prompt(){
  user_prompt "128t-support is ready. Would you like to start it now (y/n)?"
  if [ $? -eq 0 ] ; then
    # Yes, start it.
    service_ctl start
  fi
  user_prompt "Would you like 128t-support to start automatically on system boot (y/n)?"
  if [ $? -eq 0 ] ; then
    # Yes, enable it
    service_ctl enable
  elif [ $? -eq 1 ]; then
    # No, disable it
    service_ctl disable
  fi
}

#
# Script start
#

# Make sure script is run with elevated privilages
sudo_check
# Print pretty banner
print_header

# If command arg is 'nuke'
if [[ $1 = "nuke" ]]; then
  echo ""
  user_prompt "Are you sure you want to completely remove 128t-support (y/n)?"
  if [ $? -eq 0 ] ; then
    # Yes, nuke
    nuke
  elif [ $? -eq 1 ]; then
    # No, exit
    echo ""
    echo "128t-support removal cancelled."
    echo ""
    exit 0
  fi
fi

# Verify files and directories are in place
verify_install
if [ $? -ne 0 ] ; then
  # Files and directories not in place...needs set up.
  echo ""
  echo "128t-support has not been set up."
  echo ""
  user_prompt "Do you want to set up 128t-support (y/n)?"
  if [ $? -eq 0 ] ; then
    # Yes, begin setup.
    init
    echo ""
    echo "128t-support is set up, but still needs a pin number."
    echo "Obtain a pin number for this system from your 128 Technology support representative."
    echo ""
    user_prompt "Do you have a pin now, and would like to provision it (y/n)?"
    if [ $? -eq 0 ] ; then
      # Yes, set up a pin number
      echo ""
      set_pin
      start_enable_prompt
      echo ""
      echo "Finished. Re-run '128t-support' again at any time to see status or change settings."
      echo "Goodbye!"
      echo ""
      exit 0
    elif [ $? -eq 1 ]; then
      # No, exit
      echo ""
      echo "Run '128t-support' again once you have the pin number."
      echo "Goodbye!"
      echo ""
      exit 0
    fi

  elif [ $? -eq 1 ]; then
    # No, exit
    echo ""
    echo "Finished. Re-run '128t-support' again at any time to see status or change settings."
    echo "Goodbye!"
    echo ""
    exit 0
  fi

else
  # Files and directories in place...see if a pin is established
  check_pin
  if [ $? -ne 0 ] ; then
    # install verified but pin not set
    echo ""
    echo "128t-support is set up, but still needs a pin number."
    echo "Obtain a pin number for this system from your 128 Technology support representative."
      echo ""
      user_prompt "Do you have a pin now, and would like to provision it (y/n)?"
      if [ $? -eq 0 ] ; then
        # Yes, set up a pin number
        echo ""
        set_pin
        start_enable_prompt
      fi
      echo ""
      echo "Finished. Re-run '128t-support' again at any time to see status or change settings."
      echo "Goodbye!"
      echo ""
      exit 0

  else
    # pin set and install verified
    if [[ $1 = "init" ]]; then
      echo "$1"
    elif [[ $1 = "start" ]]; then
      service_ctl start
      sleep 1
      service_ctl status
    elif [[ $1 = "stop" ]]; then
      service_ctl stop
      sleep 1
      service_ctl status
    elif [[ $1 = "enable" ]]; then
      service_ctl enable
      sleep 1
      service_ctl status
    elif [[ $1 = "disable" ]]; then
      service_ctl disable
      sleep 1
      service_ctl status
    elif [[ $1 = "status" ]]; then
      service_ctl status
    elif [[ $1 = "pin" ]]; then
      echo ""
      echo "A pin number is already set for this host."
      user_prompt "Would you like to reset it (y/n)?"
      if [ $? -eq 0 ] ; then
        # Yes, set up a pin number
        set_pin
        exit 0
      elif [ $? -eq 1 ]; then
        # No, exit
        echo ""
        echo "Finished. Re-run '128t-support' again at any time to see status or change settings."
        echo "Goodbye!"
        echo ""
        exit 0
      fi
    elif [[ $1 = "key" ]]; then
      echo ""
      echo "Send the following key text to your 128 Technology support representative:"
      echo ""
      print_public_key
      echo ""
      echo "This key will authorize this host to connect to 128 Technology support."
      echo "To display this again at any time, just run '128t-support key'"
      echo ""
    else
      show_help
    fi
  fi
fi
