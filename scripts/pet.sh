#!/bin/bash
set -e

export PATH="$HOME/.foundry/bin:$PATH"

# Load config
SKILL_DIR="$HOME/.openclaw/skills/aavegotchi"
CONFIG_FILE="$SKILL_DIR/config.json"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: Config file not found at $CONFIG_FILE"
  exit 1
fi

# Parse config
CONTRACT=$(jq -r .contractAddress "$CONFIG_FILE")
RPC_URL=$(jq -r .rpcUrl "$CONFIG_FILE")
PRIVATE_KEY_PATH=$(jq -r .privateKeyPath "$CONFIG_FILE")
PRIVATE_KEY_ENCRYPTED=$(jq -r .privateKeyEncrypted "$CONFIG_FILE")

# Expand tilde in path
PRIVATE_KEY_PATH="${PRIVATE_KEY_PATH/#\~/$HOME}"

# Get gotchi ID from argument or use first from config
if [ -n "$1" ]; then
  GOTCHI_ID="$1"
else
  GOTCHI_ID=$(jq -r .gotchiIds[0] "$CONFIG_FILE")
fi

echo "🔍 Checking Aavegotchi #$GOTCHI_ID cooldown..."

# Check cooldown first
DATA=$(cast call "$CONTRACT" "getAavegotchi(uint256)" "$GOTCHI_ID" --rpc-url "$RPC_URL" 2>/dev/null)

if [ -z "$DATA" ]; then
  echo "❌ Failed to query gotchi"
  exit 1
fi

# Extract last pet timestamp (at position 1249 bytes = 2498 hex chars)
LAST_PET_HEX=${DATA:2498:64}

if [ -z "$LAST_PET_HEX" ] || [ "$LAST_PET_HEX" = "0000000000000000000000000000000000000000000000000000000000000000" ]; then
  echo "❌ Invalid last pet timestamp"
  exit 1
fi

LAST_PET_DEC=$((16#$LAST_PET_HEX))
NOW=$(date +%s)
TIME_SINCE=$((NOW - LAST_PET_DEC))
REQUIRED_WAIT=43260  # 12 hours + 1 minute

echo "Last pet: $(date -d @$LAST_PET_DEC '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -r $LAST_PET_DEC '+%Y-%m-%d %H:%M:%S' 2>/dev/null)"
echo "Time since: ${TIME_SINCE}s (need ${REQUIRED_WAIT}s)"

if [ $TIME_SINCE -lt $REQUIRED_WAIT ]; then
  TIME_LEFT=$((REQUIRED_WAIT - TIME_SINCE))
  HOURS=$((TIME_LEFT / 3600))
  MINS=$(((TIME_LEFT % 3600) / 60))
  SECS=$((TIME_LEFT % 60))
  echo "⏰ Cooldown active: ${HOURS}h ${MINS}m ${SECS}s remaining"
  echo "❌ Cannot pet yet - cooldown still active"
  exit 1
fi

echo "✅ Cooldown complete - ready to pet!"

# Load private key
if [ "$PRIVATE_KEY_ENCRYPTED" = "true" ]; then
  # Decrypt private key
  PRIVATE_KEY=$(gpg --quiet --decrypt "$PRIVATE_KEY_PATH" 2>/dev/null) || {
    echo "Error: Failed to decrypt private key from $PRIVATE_KEY_PATH"
    exit 1
  }
else
  # Read plain text private key
  PRIVATE_KEY=$(cat "$PRIVATE_KEY_PATH" 2>/dev/null) || {
    echo "Error: Failed to read private key from $PRIVATE_KEY_PATH"
    exit 1
  }
fi

if [ -z "$PRIVATE_KEY" ]; then
  echo "Error: Private key is empty"
  exit 1
fi

echo "🦞 Petting Aavegotchi #$GOTCHI_ID..."

# Call interact function with gotchi ID
cast send "$CONTRACT" \
  "interact(uint256[])" \
  "[$GOTCHI_ID]" \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY"

echo "✅ Aavegotchi #$GOTCHI_ID petted successfully!"
