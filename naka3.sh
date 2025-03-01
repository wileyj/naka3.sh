#!/bin/bash

set -uoe pipefail

DEBUG=1
CONFIG="./config.sh"
PROGNAME="$0"
TEMPLATES="$(dirname "$PROGNAME")/conf.in"

function debug() {
   if [ "$DEBUG" -ne 0 ]; then
      echo "DEBG [$(date +%s.%N)] $1" >/dev/stderr
   fi
}

function exit_error() {
   echo "$1" >/dev/stderr
   exit 1
}

# Get the path to the bitcoin PID file
# $1: config file
function get_bitcoind_pid_path() {
   local conf_path="$1"
   source "$conf_path"
   echo "$(conf_get_bitcoind_data_dir)/bitcoin.pid"
}

# Get the path to the bitcoin log file
# $1: config file
function get_bitcoind_logfile_path() {
   local conf_path="$1"
   source "$conf_path"
   echo "$(conf_get_bitcoind_data_dir)/bitcoin.log"
}

# Get the path to the signer PID file
# $1: config file
# $2: signer ID
function get_signer_pid_path() {
   local conf_path="$1"
   local signer_id="$2"
   source "$conf_path"
   echo "$(conf_get_basedir)/signer-${signer_id}.pid"
}

# Get the path to the signer log file
# $1: config file
# $2: signer ID
function get_signer_logfile_path() {
   local conf_path="$1"
   local signer_id="$2"
   source "$conf_path"
   echo "$(conf_get_basedir)/signer-${signer_id}.log"
}

# Get the path to the signer DB file
# $1: config file
# $2: signer ID
function get_signer_db_path() {
   local conf_path="$1"
   local signer_id="$2"
   source "$conf_path"
   echo "$(conf_get_stacks_signer_data_dir)/signer-${signer_id}.db"
}

# Get the path to the signer config template
function get_signer_template_path() {
   echo "$TEMPLATES/signer.toml.in"
}

# Get the path to the signer config file
# $1: config file
# $2: signer ID
function get_signer_config_path() {
   local conf_path="$1"
   local signer_id="$2"
   source "$conf_path"
   echo "$(conf_get_stacks_signer_data_dir)/signer-${signer_id}.toml"
}

# Get the PoX address for the signer
# $1: config file
# $2: signer ID
function get_signer_pox_address() {
   local conf_path="$1"
   local signer_id="$2"
   source "$conf_path"
   conf_get_stacks_signer_pox_address
}

# Get the signer private key
# $1: config file
# $2: signer ID
function get_signer_private_key() {
   local conf_path="$1"
   local signer_id="$2"
   source "$conf_path"
   conf_get_stacks_signer_private_key
}

# Get the path to the node's PID file
# $1: config file
# $2: node ID
function get_node_pid_path() {
   local conf_path="$1"
   local node_id="$2"
   source "$conf_path"
   echo "$(conf_get_basedir)/node-${node_id}.pid"
}

# Get the path to the node log file
# $1: config file
# $2: node ID
function get_node_logfile_path() {
   local conf_path="$1"
   local node_id="$2"
   source "$conf_path"
   echo "$(conf_get_basedir)/node-${node_id}.log"
}

# Get the path to the node chainstate dir
# $1: config file
# $2: node ID
function get_node_data_dir() {
   local conf_path="$1"
   local node_id="$2"
   source "$conf_path"
   echo "$(conf_get_stacks_node_data_dir)/node-${node_id}"
}

# Get the path to the node config file
# $1: config file
# $2: node ID
function get_node_config_path() {
   local conf_path="$1"
   local node_id="$2"
   source "$conf_path"
   echo "$(conf_get_stacks_node_data_dir)/node-${node_id}.toml"
}

# Get the path to the node config template
function get_node_template_path() {
   echo "$TEMPLATES/stacks-node.toml.in"
}

# Get the path to the node's event observer config template
function get_node_event_observer_template_path() {
   echo "$TEMPLATES/stacks-node-event-observer.toml.in"
}


# Run bitcoind
# $1: p2p port
# $2: rpc port
# $3: data directory
# $4: logfile
# $5: pidfile
function run_bitcoind() {
   local port="$1"
   local rpcport="$2"
   local datadir="$3"
   local logfile="$4"
   local pidfile="$5"
   local pid

   bitcoind \
      --regtest \
      --nodebug \
      --nodebuglogfile \
      --rest \
      --txindex=1 \
      --server=1 \
      --listenonion=0 \
      --rpcbind=0.0.0.0 \
      --port="$port" \
      --rpcport="$rpcport" \
      --datadir="$datadir" \
      --rpcuser="naka3" \
      --rpcpassword="naka3" > "$logfile" 2>&1 &

   pid="$!"
   echo "$pid" > "$pidfile"

   debug "Bitcoind started: pid $pid"
}

# Run a signer
# $1: signer config file
# $2: logfile
# $3: pidfile
function run_signer() {
   local signer_conf="$1"
   local logfile="$2"
   local pidfile="$3"
   local pid

   set -e
   # BLOCKSTACK_DEBUG=1 STACKS_LOG_DEBUG=1 RUST_BACKTRACE=full stacks-signer check-config -c "$signer_conf" >/dev/null 2>&1 || exit_error "Invalid signer config"
   RUST_BACKTRACE=full stacks-signer check-config -c "$signer_conf" >/dev/null 2>&1 || exit_error "Invalid signer config"
   set +e

   # BLOCKSTACK_DEBUG=1 STACKS_LOG_DEBUG=1 RUST_BACKTRACE=full stacks-signer run -c "$signer_conf" > "$logfile" 2>&1 &
   RUST_BACKTRACE=full stacks-signer run -c "$signer_conf" > "$logfile" 2>&1 &
   pid="$!"
   
   echo "$pid" > "$pidfile"

   debug "Signer started: PID $pid"
}

# Run a node
# $1: node config file
# $2: logfile
# $3: pidfile
function run_node() {
   local node_conf="$1"
   local logfile="$2"
   local pidfile="$3"
   local pid

   # BLOCKSTACK_DEBUG=1 STACKS_LOG_DEBUG=1 RUST_BACKTRACE=full stacks-node start --config "$node_conf" > "$logfile" 2>&1 &
   RUST_BACKTRACE=full stacks-node start --config "$node_conf" > "$logfile" 2>&1 &
   pid="$!"
   
   echo "$pid" > "$pidfile"

   debug "Node started: PID $pid"
}

# Start bitcoind
# Writes the PID to the given .pid file
# $1: config file
# $2: resume (true|false)
function start_bitcoind() {
   local conf_path="$1"
   local resume="$2"
   local pid_path
   local port
   local rpcport
   local datadir
   local rc

   source "$conf_path"
   pid_path="$(get_bitcoind_pid_path "$conf_path")"
   logfile="$(get_bitcoind_logfile_path "$conf_path")"

   # NOTE: these functions are loaded from conf_path
   port="$(conf_get_bitcoind_p2p_port)"
   rpcport="$(conf_get_bitcoind_rpc_port)"
   datadir="$(conf_get_bitcoind_data_dir)"

   if [ -f "$pid_path" ]; then
      echo "(already running $(cat "$pid_path"))"
      return 0
   fi
   
   if [ -d "$datadir" ] && [[ "$resume" != "true" ]]; then
      rm -rf "$datadir"
      mkdir -p "$datadir"
   fi

   run_bitcoind "$port" "$rpcport" "$datadir" "$logfile" "$pid_path"

   # wait for it to start up
   while true; do
      set +e
      bitcoin-cli -rpcconnect="127.0.0.1:$rpcport" -rpcuser="naka3" -rpcpassword="naka3" ping 2>/dev/null
      rc=$?
      set -e

      if [ $rc -eq 0 ]; then
         break
      fi
      
      sleep 1
   done

   echo "PID $(cat "$pid_path")"
   return 0
}

# Make a signer config file
# $1: config file
# $2: signer ID
# $3: template file
# prints the path
function make_signer_config() {
   local conf_path="$1"
   local signer_id="$2"
   local template_path="$3"
   local port
   local rpcport
   local key
   local host
   local signer_host
   local signer_port
   local dbfile
   local signer_conf_path

   if ! [ -f "$template_path" ]; then
      exit_error "No such file or directory: $template_path"
   fi
   
   dbfile="$(get_signer_db_path "$conf_path" "$signer_id")"
   signer_conf_path="$(get_signer_config_path "$conf_path" "$signer_id")"
   
   source "$conf_path"
   
   rm -f "$dbfile"

   # NOTE: these functions are loaded from conf_path
   port="$(conf_get_stacks_p2p_port)"
   rpcport="$(conf_get_stacks_rpc_port)"
   key="$(conf_get_stacks_signer_key)"
   host="$(conf_get_stacks_host)"
   signer_host="$(conf_get_stacks_signer_host)"
   signer_port="$(conf_get_stacks_signer_port)"

   sed -r \
      -e "s!@@SIGNER_KEY@@!$key!g" \
      -e "s!@@STACKS_HOST@@!$host!g" \
      -e "s!@@STACKS_RPC_PORT@@!$rpcport!g" \
      -e "s!@@SIGNER_DB@@!$dbfile!g" \
      -e "s!@@SIGNER_HOST@@!$signer_host!g" \
      -e "s!@@SIGNER_PORT@@!$signer_port!g" \
      "$template_path" > "$signer_conf_path"

   echo "$signer_conf_path"
   return 0
}

# Start a signer
# Writes the PID to the given .pid file
# $1: config file
# $2: signer ID
# prints the result
function start_signer() {
   local conf_path="$1"
   local signer_id="$2"
   local pid_path
   local signer_config_template_path
   local signer_config_path

   pid_path="$(get_signer_pid_path "$conf_path" "$signer_id")"
   logfile="$(get_signer_logfile_path "$conf_path" "$signer_id")"
   signer_config_template_path="$(get_signer_template_path)"
   signer_config_path="$(make_signer_config "$conf_path" "$signer_id" "$signer_config_template_path")"

   if [ -f "$pid_path" ]; then
      echo "(already running $(cat "$pid_path"))"
      return 0
   fi

   run_signer "$signer_config_path" "$logfile" "$pid_path"

   echo "PID $(cat "$pid_path")"
   return 0
}

# Make a stacks node config file
# Call this _after_ generating signer config files
# $1: config file
# $2: node ID
# $3: template file
# $4: event observer template file
# $5: miner (true/false)
# $6: stacker (true/false)
# $7: associated signer IDs as a CSV (pass 'none' if there is none)
# prints the path
function make_node_config() {
   local conf_path="$1"
   local node_id="$2"
   local template_path="$3"
   local event_observer_template_path="$4"
   local miner="$5"
   local stacker="$6"
   local signers="$7"

   local port
   local rpcport
   local miner_key
   local btc_host
   local btc_port
   local btc_rpcport
   local node_conf_path
   local datadir
   local seed_host
   local seed_port
   local stacks_host
   local signer_datadir

   if ! [ -f "$template_path" ]; then
      exit_error "No such file or directory: $template_path"
   fi
   
   datadir="$(get_node_data_dir "$conf_path" "$node_id")"
   node_conf_path="$(get_node_config_path "$conf_path" "$node_id")"
   
   source "$conf_path"
   
   # NOTE: these functions are loaded from conf_path
   port="$(conf_get_stacks_p2p_port)"
   rpcport="$(conf_get_stacks_rpc_port)"
   btc_host="$(conf_get_bitcoind_host)"
   btc_port="$(conf_get_bitcoind_p2p_port)"
   btc_rpcport="$(conf_get_bitcoind_rpc_port)"
   seed_pubkey="$(conf_get_seed_pubkey)"
   seed_host="$(conf_get_seed_host)"
   seed_port="$(conf_get_seed_p2p_port)"
   miner_key="$(conf_get_stacks_miner_key)"
   stacks_host="$(conf_get_stacks_host)"
   peer_key="$(conf_get_stacks_peer_key)"

   sed -r \
      -e "s!@@STACKS_RPC_PORT@@!$rpcport!g" \
      -e "s!@@STACKS_P2P_PORT@@!$port!g" \
      -e "s!@@STACKS_PUBLIC_HOST@@!$stacks_host!g" \
      -e "s!@@SEED_NODE_HOST@@!$seed_host!g" \
      -e "s!@@SEED_NODE_P2P_PORT@@!$seed_port!g" \
      -e "s!@@SEED_NODE_PUBKEY@@!$seed_pubkey!g" \
      -e "s!@@STACKS_MINER_KEY@@!$miner_key!g" \
      -e "s!@@STACKS_PEER_KEY@@!$peer_key!g" \
      -e "s!@@STACKS_MINER@@!$miner!g" \
      -e "s!@@STACKS_STACKER@@!$stacker!g" \
      -e "s!@@BITCOIN_HOST@@!$btc_host!g" \
      -e "s!@@BITCOIN_P2P_PORT@@!$btc_port!g" \
      -e "s!@@BITCOIN_RPC_PORT@@!$btc_rpcport!g" \
      -e "s!@@STACKS_DATA_DIR@@!$datadir!g" \
      "$template_path" > "$node_conf_path"

   if [ "$signers" != "none" ]; then
      # load up all signer endpoints
      signer_datadir="$(conf_get_stacks_signer_data_dir)"
      
      local signer_conf
      local endpoint
      local signer_host
      local signer_port
      local cur_signer
      local remaining_signers

      signers="$signers,"
      while [ -n "$signers" ]; do
         signers="${signers#,}"
         remaining_signers="${signers#*,}"
         cur_signer="${signers%"$remaining_signers"}"
         cur_signer="${cur_signer%,}"

         signers="$remaining_signers"

         debug "Add signer '$cur_signer', remaining is '$signers'"

         signer_conf="$signer_datadir/signer-${cur_signer}.toml"
         # extract the endpoint
         endpoint="$(grep -E "^endpoint[^=]*=" "$signer_conf" | \
            sed -r 's/^endpoint[^=]*=[ ]*"(.+)"[ ]*$/\1/g')"

         # extract host and port
         signer_host="${endpoint%:*}"
         signer_port="${endpoint#*:}"

         if [ "$signer_host" = "0.0.0.0" ]; then
            signer_host="127.0.0.1"
         fi

         sed -r \
            -e "s!@@SIGNER_ENDPOINT@@!$signer_host:$signer_port!g" \
            "$event_observer_template_path" >> "$node_conf_path"
      done
   fi

   echo "$node_conf_path"
   return 0
}

# Set a fault injection in the existing node config.
# $1: config file path
# $2: fault name
# $3: fault value
function add_node_fault_injection() {
   local node_config_path="$1"
   local fault_name="$2"
   local fault_value="$3"

   if ! [ -f "$node_config_path" ]; then 
      exit_error "No such file or directory: $conf_path"
   fi

   sed -i \
      -e "s!# @@${fault_name}@@!${fault_name} = ${fault_value}!g" \
      "$node_config_path"

   return 0
}

# Start a stacks node.
# Call _after_ generating signer configs
# Writes the PID to the given .pid file
# $1: config file
# $2: node ID
# prints the result
function start_node() {
   local conf_path="$1"
   local node_id="$2"
   local pid_path
   local datadir

   node_config_path="$(get_node_config_path "$conf_path" "$node_id")"
   if ! [ -f "$node_config_path" ]; then
      exit_error "ERROR: cannot start node $node_id: no such config file $node_config_path"
   fi

   pid_path="$(get_node_pid_path "$conf_path" "$node_id")"
   logfile="$(get_node_logfile_path "$conf_path" "$node_id")"
   datadir="$(get_node_data_dir "$conf_path" "$node_id")"

   if [ -f "$pid_path" ]; then
      echo "(already running $(cat "$pid_path"))"
      return 0
   fi

   if [ -d "$datadir" ]; then
      echo "rm -rf '$datadir'"
      mkdir -p "$datadir"
   fi

   run_node "$node_config_path" "$logfile" "$pid_path"

   echo "PID $(cat "$pid_path")"
   return 0
}

# Stop a process
# $1: pid path
function stop_process() {
   local pid_path="$1"
   local rc
   if ! [ -f "$pid_path" ]; then
      echo "(not running)"
      rm -f "$pid_path"
      return 0
   fi

   pid="$(cat "$pid_path")"

   set +e
   kill -s SIGTERM "$pid" 2>/dev/null
   rc=$?

   if [ $rc -ne 0 ]; then
      kill -s 0 "$pid" 2>/dev/null
      rc=$?
      if [ $rc -ne 0 ]; then
         echo "(not running)"
         rm -f "$pid_path"
         set -e
         return 0
      fi
   else
      waitpid "$pid" 2>/dev/null
   fi

   set -e
   rm -f "$pid_path"
   echo "done"
}

# Stop bitcoind
# $1: conf file
function stop_bitcoind() {
   local conf_path="$1"
   local pid_path
   local pid
   local rc
   
   source "$conf_path"
   pid_path="$(get_bitcoind_pid_path "$conf_path")"
   stop_process "$pid_path"
}

# Stop the signer
# $1: conf file
# $2: signer id
function stop_signer() {
   local conf_path="$1"
   local signer_id="$2"
   local pid_path
   local pid
   
   source "$conf_path"
   pid_path="$(get_signer_pid_path "$conf_path" "$signer_id")"
   stop_process "$pid_path"
}

# Stop the node
# $1: conf file
# $2: node id
function stop_node() {
   local conf_path="$1"
   local node_id="$2"
   local pid_path
   local pid
   
   source "$conf_path"
   pid_path="$(get_node_pid_path "$conf_path" "$node_id")"
   stop_process "$pid_path"
}

# Run a bitcoin-cli command
# $1: config path
# arguments are all passed to bitcoin-cli
function run_bitcoin_cli() {
   local conf_path="$1"
   local rpcport

   source "$conf_path"
   rpcport="$(conf_get_bitcoind_rpc_port)"

   shift 1
   bitcoin-cli -rpcconnect=127.0.0.1 -rpcport="$rpcport" -rpcuser=naka3 -rpcpassword=naka3 -rpcwallet=main "$@"
}

# Run a blockstack-cli command
# arguments are all passed to blockstack-cli
function run_blockstack_cli() {
   blockstack-cli --testnet "$@"
}

# Tail a log file
# Keep trying even if it doesn't exist
# $1: logfile path
function follow_logs() {
   local logfile="$1"
   while true; do
      if ! [ -f "$logfile" ]; then 
         echo "Waiting for $logfile to become available..."
         sleep 1
         continue
      fi
      tail -f "$logfile"
   done
}

# Convert a byte stream to a hex string
# from https://stackoverflow.com/questions/9515007/linux-script-to-convert-byte-data-into-a-hex-string
function hex_encode() {
   od -An -v -tx1 | tr -d ' \n'
}

# Decode b58 text into a hex byte stream
# $1: base58 text
# from https://github.com/grondilu/bitcoin-bash-tools
function b58_decode() {
   local base58_chars="123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxy"
   local b58text="$1"
   if [[ "$b58text" =~ ^(1*)([$base58_chars]+)$ ]]; then
      dc -e "${BASH_REMATCH[1]//1/0P} 0${base58_chars//?/ds&1+} 0${BASH_REMATCH[2]//?/ 58*l&+}P" | hex_encode
   else
      return 1
   fi
}

# Decode a base58 Bitcoin address into "$version_byte $hash_bytes"
# $1: address
# prints the above
function b58_address_decode() {
   local addr="$1"
   b58_decode "$addr" | sed -r 's/^([0-9a-f]{2})([0-9a-f]{40}).+$/\1 \2#/g' | tr '#' '\n'
}

# Make a signer's stacking transaction
# $1: config
# $2: signer ID
# $3: reward cycle
# $4: max amount
# $5: nonce
# $6: auth ID
function make_stacking_tx() {
   local conf_file="$1"
   local signer_id="$2"
   local reward_cycle="$3"
   local max_amount="$4"
   local nonce="$5"
   local auth_id="$6"
   local stacking_function="$7"
   local signer_config_path
   local pox_address
   local signer_json
   local signer_pubkey
   local signer_signature
   local signer_privkey
   local address_parts
   local address_version
   local hash_bytes
   local start_burn_block=$((reward_cycle * 20 + 1))
   local cycles

   signer_config_path="$(get_signer_config_path "$conf_file" "$signer_id")"
   signer_privkey="$(get_signer_private_key "$conf_file" "$signer_id")"
   pox_address="$(get_signer_pox_address "$conf_file" "$signer_id")"

   address_parts="$(b58_address_decode "$pox_address")"
   address_version="$(echo "$address_parts" | cut -d ' ' -f 1)"
   if [ "$address_version" != "6f" ]; then
      exit_error "Only support testnet p2pkh"
   fi
   hash_bytes="$(echo "$address_parts" | cut -d ' ' -f 2)"

   case "$stacking_function" in
      "stack-stx") cycles=2 ;;
      *) cycles=1 ;;
   esac
   debug "Generating stacking signature for extend with the following parameters:"
   debug "  Stacking Function: $stacking_function"
   debug "  POX Address: $pox_address"
   debug "  Reward Cycle: $reward_cycle"
   debug "  Config: $signer_config_path"
   debug "  Method: $stacking_function"
   debug "  Max Amount: $max_amount"
   debug "  Auth ID: $auth_id"
   debug "  Period: $cycles"
   signer_json="$(stacks-signer generate-stacking-signature \
      --pox-address "$pox_address" \
      --reward-cycle "$reward_cycle" \
      --config "$signer_config_path" \
      --method "$stacking_function" \
      --period $cycles \
      --max-amount "$max_amount" \
      --auth-id "$auth_id" \
      | (
         local line
         local pubkey
         local sig
         while read -r line; do
            if [[ "$line" =~ "Signer Public Key:" ]]; then
               pubkey="$(echo "$line" | cut -d ':' -f 2 | sed -r 's/ //g')"
            elif [[ "$line" =~ "Signer Key Signature:" ]]; then
               sig="$(echo "$line" | cut -d ':' -f 2 | sed -r 's/ //g')"
            fi
         done
         echo "{\"pubkey\": \"$pubkey\", \"sig\": \"$sig\"}"
      )
   )"

   signer_pubkey="$(echo "$signer_json" | jq -r '.pubkey')"
   signer_signature="$(echo "$signer_json" | jq -r '.sig')"

   if [ "$stacking_function" == "stack-stx" ];then
      debug "  Sending $stacking_function tx"
      run_blockstack_cli contract-call \
         "$signer_privkey" \
         1000 \
         "$nonce" \
         "ST000000000000000000002AMW42H" \
         "pox-4" \
         "$stacking_function" \
         -e "u${max_amount}" \
         -e "{ version: 0x00, hashbytes: 0x${hash_bytes} }" \
         -e "u${start_burn_block}" \
         -e "u${cycles}" \
         -e "(some ${signer_signature})" \
         -e "${signer_pubkey}" \
         -e "u${max_amount}" \
         -e "u${auth_id}"
   fi
   if [ "$stacking_function" == "stack-extend" ];then
      debug "  Sending $stacking_function tx"
      run_blockstack_cli contract-call \
      "$signer_privkey" \
      1000 \
      "$nonce" \
      "ST000000000000000000002AMW42H" \
      "pox-4" \
      "$stacking_function" \
      -e "u${cycles}" \
      -e "{ version: 0x00, hashbytes: 0x${hash_bytes} }" \
      -e "(some ${signer_signature})" \
      -e "${signer_pubkey}" \
      -e "u${max_amount}" \
      -e "u${auth_id}"
   fi
}

# Get an account's nonce
# $1: config
# $2: address
function get_account_nonce() {
   local conf_path="$1"
   local address="$2"
   local stacks_host
   local stacks_port
   local nonce

   stacks_host="$(conf_get_seed_host)"
   stacks_port="$(conf_get_seed_rpc_port)"
   nonce="$(curl -sL "http://${stacks_host}:${stacks_port}/v2/accounts/${address}?proof=0" | jq -r '.nonce')"
   echo "$nonce"
}

# Send a transaction
# $1: transaction hex
# $2: host 
# $3: port
function send_tx() {
   local tx="$1"
   local stacks_host="$2"
   local stacks_port="$3"

   local content_length

   content_length="${#tx}"
   content_length=$((content_length / 2))

   echo -e "$tx" | xxd -r -p | \
      curl -sL -X POST -H "content-type: application/octet-stream" -H "content-length: $content_length" --data-binary @- "http://${stacks_host}:${stacks_port}/v2/transactions"
}

# Make a stx-transfer transaction.
# Automatically fetches the right nonce.
# The fee rate is hard-coded to 360, which is 2x a single-sig stx-transfer's length
# $1: config
# $2: private key
# $3: amount
# $4: recipient address
# $5: memo
function make_stx_transfer() {
   local conf_file="$1"
   local private_key="$2"
   local amount="$3"
   local recipient="$4"
   local memo="$5"
   local address
   local nonce

   address="$(run_blockstack_cli addresses "$private_key" | jq -r '.STX')"
   nonce="$(get_account_nonce "$conf_file" "$address")"

   run_blockstack_cli token-transfer \
      "$private_key" \
      "360" \
      "$nonce" \
      "$recipient" \
      "$amount" \
      "$memo"
}

# Continuously send a stx-transfer transaction from an address, for a given amount, to a given recipient
# $1: config
# $2: private key
# $3: amount
# $4: recipient address
# $5: sleep time between transmission
# $6: abort file -- if this file exists, then this loop breaks
function begin_stx_transfers() {
   local conf_file="$1"
   local private_key="$2"
   local amount="$3"
   local recipient="$4"
   local sleep_time="$5"
   local abort_file="$6"

   local tx
   local stacks_host
   local stacks_port
   local content_length
   local address
   local nonce
   local response
   
   address="$(run_blockstack_cli addresses "$private_key" | jq -r '.STX')"
   nonce="$(get_account_nonce "$conf_file" "$address")"
   stacks_host="$(conf_get_seed_host)"
   stacks_port="$(conf_get_seed_rpc_port)"

   while ! [ -f "$abort_file" ]; do
      tx="$(run_blockstack_cli token-transfer \
         "$private_key" \
         "360" \
         "$nonce" \
         "$recipient" \
         "$amount" \
         "naka3")"

      content_length="${#tx}"
      content_length=$((content_length / 2))

      set -e
      response="$(send_tx "$tx" "$stacks_host" "$stacks_port")"
      if [ -z "$(echo "$response" | jq -r '.error' 2>/dev/null)" ]; then
         nonce=$((nonce + 1))
      fi
      set +e

      sleep "$sleep_time"
   done
}

# Stop a running begin_stx_transfers loop
# $1: abort file
function end_stx_transfers() {
   local abort_file="$1"

   touch "$abort_file"
}

# Print usage and exit 
# $1: subcommand usage
function usage() {
   local cmd="$1"
   case "$cmd" in
      bitcoind)
         exit_error "Usage: $PROGNAME bitcoind start|resume|stop|mine|peer"
         ;;
      bitcoin-cli)
         exit_error "Usage: $PROGNAME bitcoin-cli [args...]"
         ;;
      signer)
         exit_error "Usage: $PROGNAME signer [signer_id] config|start|stop|logs|stack-tx"
         ;;
      node)
         exit_error "Usage: $PROGNAME node [node_id] config-miner|config-follower|config-miner-stacker|config-follower-stacker|miner-addr|start|stop|logs"
         ;;
      tx)
         exit_error "Usage: $PROGNAME tx transfer|begin-transfers|end-transfers [args...]"
         ;;
      "$PROGNAME")
         exit_error "Need a command"
         ;;
      *)
         exit_error "Unrecognized command '$cmd'. Options are bitcoind, bitcoin-cli, signer, node, tx"
         ;;
   esac
}

function main() {
   local cmd
   set +ue
   cmd="$1"
   set -ue

   debug "Command is '$cmd'"
   case "$cmd" in 
      bitcoind)
         local subcmd="$2"
         debug "Subcmmand is '$subcmd'"

         case "$subcmd" in
            start)
               echo -n "Starting bitcoind... "
               start_bitcoind "$CONFIG" "false"

               echo -n "Instantiating 'main' wallet... "
               run_bitcoin_cli "$CONFIG" createwallet "main" true >/dev/null 2>&1

               echo "OK"
               ;;

            resume)
               echo -n "Resuming bitcoind..."
               start_bitcoind "$CONFIG" "true"
               
               run_bitcoin_cli "$CONFIG" loadwallet "main" >/dev/null 2>&1 
               echo "OK"
               ;;

            stop)
               echo -n "Stopping bitcoind... "
               stop_bitcoind "$CONFIG"
               ;;

            mine)
               set +ue
               local num_blocks="$3"
               local addr="$4"

               if [ -z "$num_blocks" ] || [ -z "$addr" ]; then
                  echo >&2 "Number of blocks and/or address not given"
                  usage "bitcoind"
               fi
               set -ue

               run_bitcoin_cli "$CONFIG" generatetoaddress "$num_blocks" "$addr"
               ;;

            getblockcount)
               run_bitcoin_cli "$CONFIG" getblockcount
               ;;

            peer)
               set +ue
               local peer_addr="$3"
               local peer_port="$4"

               if [ -z "$peer_addr" ] || [ -z "$peer_port" ]; then
                  echo >&2 "Missing peer addr and/or port"
                  usage "bitcoind"
               fi
               set -ue

               echo -n "Peering $peer_addr:$peer_port..."

               run_bitcoin_cli "$CONFIG" addnode "$peer_addr:$peer_port" "add"
               echo "OK"
               ;;

            *)
               usage "bitcoind"
               ;;
         esac
         ;;

      bitcoin-cli)
         shift 1
         run_bitcoin_cli "$CONFIG" "$@"
         ;;

      signer)
         set +ue
         local signer_id="$2"
         debug "Signer ID is '$signer_id'"

         local subcmd="$3"
         debug "Subcommand is '$subcmd'"
         set -ue

         if [ -z "$signer_id" ]; then
            echo >&2 "Signer ID not given"
            usage "signer"
         fi

         if [ -z "$subcmd" ]; then
            echo >&2 "Subcommand not given"
            usage "signer"
         fi

         case "$subcmd" in
            config|configure|make-config)
               echo -n "Making config for signer '$signer_id'... "
               local signer_config_path
               signer_config_path="$(make_signer_config "$CONFIG" "$signer_id" "$(get_signer_template_path)")"

               echo "$signer_config_path"
               ;;

            start)
               echo -n "Starting signer '$signer_id'... "
               start_signer "$CONFIG" "$signer_id"
               ;;

            stop)
               echo -n "Stopping signer '$signer_id'... "
               stop_signer "$CONFIG" "$signer_id"
               ;;
            
            logs)
               local signer_logfile_path
               signer_logfile_path="$(get_signer_logfile_path "$CONFIG" "$signer_id")"
               follow_logs "$signer_logfile_path"
               ;;

            stack-tx)
               set +ue
               local reward_cycle="$4"
               debug "Reward cycle is '$reward_cycle'"

               local max_amount="$5"
               debug "Max amount is '$max_amount'"

               local nonce="$6"
               debug "Nonce is $nonce"

               local auth_id="$7"
               debug "Auth ID is $auth_id"

               if [ -z "$reward_cycle" ]; then
                  echo >&2 "Reward cycle missing"
                  usage "signer"
               fi

               if [ -z "$max_amount" ]; then
                  echo >&2 "Max amount missing"
                  usage "signer"
               fi

               if [ -z "$nonce" ]; then
                  echo >&2 "Nonce is missing"
                  usage "signer"
               fi

               if [ -z "$auth_id" ]; then
                  echo >&2 "Auth ID is missing"
                  usage "signer"
               fi

               set -ue

               make_stacking_tx "$CONFIG" "$signer_id" "$reward_cycle" "$max_amount" "$nonce" "$auth_id" "stack-stx"
               ;;

            stack-extend)
               set +ue
               local reward_cycle="$4"
               debug "Reward cycle is '$reward_cycle'"

               local max_amount="$5"
               debug "Max amount is '$max_amount'"

               local nonce="$6"
               debug "Nonce is $nonce"

               local auth_id="$7"
               debug "Auth ID is $auth_id"

               debug "**************** Calling stack-extend ****************"
               make_stacking_tx "$CONFIG" "$signer_id" "$reward_cycle" "$max_amount" "$nonce" "$auth_id" "stack-extend"
               ;;

            *)
               usage "signer"
               ;;
         esac
         ;;
      
      node)
         set +ue
         local node_id="$2"
         debug "Node ID is '$node_id'"

         local subcmd="$3"
         debug "Subcommand is '$subcmd'"
         set -ue

         if [ -z "$node_id" ]; then
            usage "node"
         fi

         if [ -z "$subcmd" ]; then
            usage "node"
         fi

         case "$subcmd" in
            miner-addr|miner-address)
               local node_config_path
               local seed
               node_conf_path="$(get_node_config_path "$CONFIG" "$node_id")"
               seed="$(grep -E "^seed[ ]*=" "$node_conf_path" | sed -r 's/^seed[ ]*=[ ]*"([^ "]+)"[ ]*$/\1/g')"
               run_blockstack_cli "addresses" "$seed"
               ;;

            config-miner)
               echo -n "Making miner config for node '$node_id'... "
               set +ue
               local signers="$4"
               debug "Signers is '$signers'"

               if [ -z "$signers" ]; then
                  signers="none"
               fi
               set -ue

               local node_config_path
               node_config_path="$(make_node_config "$CONFIG" "$node_id" "$(get_node_template_path)" "$(get_node_event_observer_template_path)" "true" "false" "$signers")"

               echo "$node_config_path"
               ;;
            
            config-miner-stacker)
               echo -n "Making miner-stacker config for node '$node_id'... "
               set +ue
               local signers="$4"
               debug "Signers is '$signers'"

               if [ -z "$signers" ]; then
                  signers="none"
               fi
               set -ue

               local node_config_path
               node_config_path="$(make_node_config "$CONFIG" "$node_id" "$(get_node_template_path)" "$(get_node_event_observer_template_path)" "true" "true" "$signers")"

               echo "$node_config_path"
               ;;
            
            config-follower)
               echo -n "Making follower config for node '$node_id'... "
               set +ue
               local signers="$4"
               debug "Signers is '$signers'"

               if [ -z "$signers" ]; then
                  signers="none"
               fi
               set -ue

               local node_config_path
               node_config_path="$(make_node_config "$CONFIG" "$node_id" "$(get_node_template_path)" "$(get_node_event_observer_template_path)" "false" "false" "$signers")"

               echo "$node_config_path"
               ;;
            
            config-follower-stacker)
               echo -n "Making follower-stacker config for node '$node_id'... "
               set +ue
               local signers="$4"
               debug "Signers is '$signers'"

               if [ -z "$signers" ]; then
                  signers="none"
               fi
               set -ue

               local node_config_path
               node_config_path="$(make_node_config "$CONFIG" "$node_id" "$(get_node_template_path)" "$(get_node_event_observer_template_path)" "false" "true" "$signers")"

               echo "$node_config_path"
               ;;

            config-fault-injection)
               echo -n "Setting fault-injection for node '$node_id'..."
               set +ue
               local fault_name="$4"
               local fault_value="$5"
               debug "Fault name is '$fault_name'"
               debug "Fault value is '$fault_value'"

               if [ -z "$fault_name" ]; then
                  usage "node"
               fi
               if [ -z "$fault_value" ]; then
                  usage "node"
               fi
               set -ue

               local node_config_path
               node_config_path="$(get_node_config_path "$CONFIG" "$node_id")"
               add_node_fault_injection "$node_config_path" "$fault_name" "$fault_value"
               echo "$fault_name"
               ;;

            start)
               echo -n "Starting node '$node_id'... "
               start_node "$CONFIG" "$node_id"
               ;;

            stop)
               echo -n "Stopping node '$node_id'... "
               stop_node "$CONFIG" "$node_id"
               ;;

            logs)
               local node_logfile_path
               node_logfile_path="$(get_node_logfile_path "$CONFIG" "$node_id")"
               follow_logs "$node_logfile_path"
               ;;

            send-tx)
               local node_config_path
               local stacks_host
               local rpcport
               local content_length

               set +ue
               local tx="$4"
               if [ -z "$tx" ]; then
                  echo >&2 "No tx given"
                  usage "node"
               fi
               set -ue
      
               source "$CONFIG"
               
               node_conf_path="$(get_node_config_path "$CONFIG" "$node_id")"
               stacks_host="$(conf_get_stacks_host)"
               rpcport="$(conf_get_stacks_rpc_port)"

               send_tx "$tx" "$stacks_host" "$rpcport"
               ;;
               
            *)
               usage "node"
               ;;
         esac
         ;;

      tx)
         local subcmd="$2"
         debug "Subcmmand is '$subcmd'"
         case "$subcmd" in
            transfer)
               local private_key
               local amount
               local recipient

               set +ue
               private_key="$3"
               amount="$4"
               recipient="$5"
               memo="$6"
               set -ue

               if [ -z "$private_key" ]; then
                  echo >&2 "No private key given"
                  usage "tx"
               fi
               if [ -z "$amount" ]; then
                  echo >&2 "No amount given"
                  usage "tx"
               fi
               if [ -z "$recipient" ]; then
                  echo >&2 "No recipient given"
                  usage "tx"
               fi

               source "$CONFIG"
               make_stx_transfer "$CONFIG" "$private_key" "$amount" "$recipient" "$memo"
               ;;

            begin-transfers)
               local private_key
               local amount
               local recipient
               local sleep_time
               local abort_file
               
               set +ue
               private_key="$3"
               amount="$4"
               recipient="$5"
               sleep_time="$6"
               abort_file="$7"
               set -ue
               
               if [ -z "$private_key" ]; then
                  echo >&2 "No private key given"
                  usage "tx"
               fi
               if [ -z "$amount" ]; then
                  echo >&2 "No amount given"
                  usage "tx"
               fi
               if [ -z "$recipient" ]; then
                  echo >&2 "No recipient given"
                  usage "tx"
               fi
               if [ -z "$sleep_time" ]; then
                  echo >&2 "No sleep time given"
                  usage "tx"
               fi
               if [ -z "$abort_file" ]; then
                  echo >&2 "No abort file given"
                  usage "tx"
               fi

               source "$CONFIG"
               begin_stx_transfers "$CONFIG" "$private_key" "$amount" "$recipient" "$sleep_time" "$abort_file"
               ;;

            end-transfers)
               local abort_file
               
               set +ue
               abort_file="$3"
               set -ue
               
               if [ -z "$abort_file" ]; then
                  echo >&2 "No abort file given"
                  usage "tx"
               fi
               
               source "$CONFIG"
               end_stx_transfers "$abort_file"
               ;;

            *)
               usage "tx"
               ;;
         esac
         ;;

      *)
         usage "$cmd"
         ;;
   esac
}

while getopts "hdc:" OPT; do
   case "$OPT" in
      d)
         DEBUG=1
         shift 1
         ;;
      h)
         exit_error "Usage: $PROGNAME bitcoind|signer|node [subcommand...]"
         ;;
      c)
         CONFIG="$OPTARG"
         shift 2
         ;;
      ?)
         exit_error "Unrecognized option -${OPT}"
         ;;
   esac
done

source "$CONFIG"
conf_setup
main "$@"
