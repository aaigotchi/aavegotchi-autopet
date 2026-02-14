#!/bin/bash
export PATH="$HOME/.foundry/bin:$PATH"

CONFIG_FILE="$HOME/.openclaw/workspace/skills/aavegotchi/config.json"

CONTRACT=$(jq -r ".contractAddress" "$CONFIG_FILE")
RPC_URL=$(jq -r ".rpcUrl" "$CONFIG_FILE")
GOTCHI_IDS=$(jq -r ".gotchiIds[]" "$CONFIG_FILE")

echo "🔍 Checking Aavegotchi cooldowns..."
echo ""

for GOTCHI_ID in $GOTCHI_IDS; do
  echo "Gotchi #$GOTCHI_ID:"
  
  DATA=$(cast call "$CONTRACT" "getAavegotchi(uint256)" "$GOTCHI_ID" --rpc-url "$RPC_URL" 2>/dev/null)
  
  if [ -z "$DATA" ]; then
    echo "  ❌ Failed to query gotchi"
    echo ""
    continue
  fi
  
  # Extract last pet timestamp (at position 1249 bytes = 2498 hex chars)
  LAST_PET_HEX=${DATA:2498:64}
  
  if [ -z "$LAST_PET_HEX" ] || [ "$LAST_PET_HEX" = "0000000000000000000000000000000000000000000000000000000000000000" ]; then
    echo "  ❌ Invalid last pet timestamp"
    echo ""
    continue
  fi
  
  LAST_PET_DEC=$((16#$LAST_PET_HEX))
  NOW=$(date +%s)
  TIME_SINCE=$((NOW - LAST_PET_DEC))
  REQUIRED_WAIT=43260  # 12 hours + 1 minute
  
  echo "  Last pet: $(date -d @$LAST_PET_DEC '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -r $LAST_PET_DEC '+%Y-%m-%d %H:%M:%S' 2>/dev/null)"
  echo "  Time since: ${TIME_SINCE}s"
  
  if [ $TIME_SINCE -ge $REQUIRED_WAIT ]; then
    echo "  ✅ Ready to pet!"
  else
    TIME_LEFT=$((REQUIRED_WAIT - TIME_SINCE))
    HOURS=$((TIME_LEFT / 3600))
    MINS=$(((TIME_LEFT % 3600) / 60))
    SECS=$((TIME_LEFT % 60))
    echo "  ⏰ Cooldown: ${HOURS}h ${MINS}m ${SECS}s remaining"
  fi
  
  echo ""
done
