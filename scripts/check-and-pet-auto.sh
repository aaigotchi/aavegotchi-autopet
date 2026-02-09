#\!/bin/bash
set -e

export PATH="$HOME/.foundry/bin:$PATH"

LOG_FILE="$HOME/.openclaw/logs/aavegotchi-autopet.log"
CONFIG_FILE="$HOME/.openclaw/skills/aavegotchi/config.json"

# Load config
CONTRACT=$(jq -r ".contractAddress" "$CONFIG_FILE")
RPC_URL=$(jq -r ".rpcUrl" "$CONFIG_FILE")
GOTCHI_IDS=$(jq -r ".gotchiIds[]" "$CONFIG_FILE")

echo "$(date): 🔍 Checking gotchis..." >> "$LOG_FILE"

# Load private key once (NO PASSWORD - fully automated)
PRIVATE_KEY=$(gpg --quiet --decrypt ~/.openclaw/secrets/aavegotchi-private-key.gpg 2>/dev/null)

if [ -z "$PRIVATE_KEY" ]; then
  echo "❌ No private key found" >> "$LOG_FILE"
  exit 1
fi

# Check each gotchi
for GOTCHI_ID in $GOTCHI_IDS; do
  echo "" >> "$LOG_FILE"
  echo "Gotchi #$GOTCHI_ID:" >> "$LOG_FILE"
  
  # Get last pet time
  DATA=$(cast call "$CONTRACT" "getAavegotchi(uint256)" "$GOTCHI_ID" --rpc-url "$RPC_URL" 2>/dev/null)
  
  if [ -z "$DATA" ]; then
    echo "  ❌ Failed to query gotchi" >> "$LOG_FILE"
    continue
  fi
  
  LAST_PET_HEX=${DATA:2498:64}
  LAST_PET_DEC=$((16#$LAST_PET_HEX))
  
  NOW=$(date +%s)
  TIME_SINCE=$((NOW - LAST_PET_DEC))
  REQUIRED_WAIT=43260
  
  echo "  Last pet: $(date -d @$LAST_PET_DEC 2>/dev/null || date -r $LAST_PET_DEC 2>/dev/null)" >> "$LOG_FILE"
  echo "  Time since: ${TIME_SINCE}s (need ${REQUIRED_WAIT}s)" >> "$LOG_FILE"
  
  if [ $TIME_SINCE -ge $REQUIRED_WAIT ]; then
    echo "  ✅ Time to pet\!" >> "$LOG_FILE"
    
    # Pet this gotchi
    cast send "$CONTRACT" \
      "interact(uint256[])" \
      "[$GOTCHI_ID]" \
      --rpc-url "$RPC_URL" \
      --private-key "$PRIVATE_KEY" >> "$LOG_FILE" 2>&1
      
    echo "  🦞 Pet complete\!" >> "$LOG_FILE"
  else
    TIME_LEFT=$((REQUIRED_WAIT - TIME_SINCE))
    HOURS=$((TIME_LEFT / 3600))
    MINS=$(((TIME_LEFT % 3600) / 60))
    SECS=$((TIME_LEFT % 60))
    echo "  ⏰ Wait ${HOURS}h ${MINS}m ${SECS}s" >> "$LOG_FILE"
  fi
done

echo "$(date): ✅ Check complete" >> "$LOG_FILE"
