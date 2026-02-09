#!/bin/bash
set -e  # Exit on error, but we'll catch and log it

export PATH="$HOME/.foundry/bin:$PATH"

LOG_FILE="$HOME/.openclaw/logs/aavegotchi-autopet.log"
CONFIG_FILE="$HOME/.openclaw/skills/aavegotchi/config.json"

# Load config
CONTRACT=$(jq -r ".contractAddress" "$CONFIG_FILE")
RPC_URL=$(jq -r ".rpcUrl" "$CONFIG_FILE")
GOTCHI_IDS=$(jq -r ".gotchiIds[]" "$CONFIG_FILE")

echo "$(date): 🔍 Checking gotchis..." >> "$LOG_FILE"

# Load private key once (NO PASSWORD - fully automated)
PRIVATE_KEY=$(gpg --quiet --decrypt ~/.openclaw/secrets/aavegotchi-private-key.gpg 2>&1)

if [ -z "$PRIVATE_KEY" ]; then
  echo "$(date): ❌ No private key found" >> "$LOG_FILE"
  echo "$(date): GPG Error: $PRIVATE_KEY" >> "$LOG_FILE"
  exit 1
fi

# Check each gotchi
for GOTCHI_ID in $GOTCHI_IDS; do
  echo "" >> "$LOG_FILE"
  echo "Gotchi #$GOTCHI_ID:" >> "$LOG_FILE"

  # Get last pet time with error handling
  DATA=""
  RETRY_COUNT=0
  MAX_RETRIES=3

  while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    DATA=$(cast call "$CONTRACT" "getAavegotchi(uint256)" "$GOTCHI_ID" --rpc-url "$RPC_URL" 2>&1)
    CAST_EXIT=$?

    if [ $CAST_EXIT -eq 0 ] && [ -n "$DATA" ]; then
      break  # Success
    fi

    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "  ⚠️ Retry $RETRY_COUNT/$MAX_RETRIES: cast call failed (exit $CAST_EXIT)" >> "$LOG_FILE"

    if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
      sleep 5  # Wait before retry
    fi
  done

  if [ -z "$DATA" ]; then
    echo "  ❌ Failed to query gotchi after $MAX_RETRIES attempts" >> "$LOG_FILE"
    echo "  Last error: $DATA" >> "$LOG_FILE"
    continue
  fi

  # Extract last pet timestamp
  LAST_PET_HEX=${DATA:2498:64}

  # Validate timestamp
  if [ -z "$LAST_PET_HEX" ] || [ "$LAST_PET_HEX" = "0000000000000000000000000000000000000000000000000000000000000000000" ]; then
    echo "  ❌ Invalid last pet timestamp" >> "$LOG_FILE"
    continue
  fi

  LAST_PET_DEC=$((16#$LAST_PET_HEX))

  NOW=$(date +%s)
  TIME_SINCE=$((NOW - LAST_PET_DEC))
  REQUIRED_WAIT=43260  # 12 hours + 1 minute

  echo "  Last pet: $(date -d @$LAST_PET_DEC 2>/dev/null || date -r $LAST_PET_DEC 2>/dev/null || echo 'Unknown')" >> "$LOG_FILE"
  echo "  Time since: ${TIME_SINCE}s (need ${REQUIRED_WAIT}s)" >> "$LOG_FILE"

  if [ $TIME_SINCE -ge $REQUIRED_WAIT ]; then
    echo "  ✅ Time to pet!" >> "$LOG_FILE"

    # Pet this gotchi with error handling
    PET_RESULT=""
    PET_RETRY_COUNT=0
    PET_MAX_RETRIES=3

    while [ $PET_RETRY_COUNT -lt $PET_MAX_RETRIES ]; do
      PET_RESULT=$(cast send "$CONTRACT" \
        "interact(uint256[])" \
        "[$GOTCHI_ID]" \
        --rpc-url "$RPC_URL" \
        --private-key "$PRIVATE_KEY" 2>&1)

      PET_EXIT=$?

      if [ $PET_EXIT -eq 0 ]; then
        echo "  🦞 Pet complete! Transaction:" >> "$LOG_FILE"
        echo "$PET_RESULT" | grep -i "transactionHash\|status" >> "$LOG_FILE"
        break
      fi

      PET_RETRY_COUNT=$((PET_RETRY_COUNT + 1))
      echo "  ⚠️ Pet retry $PET_RETRY_COUNT/$PET_MAX_RETRIES: failed (exit $PET_EXIT)" >> "$LOG_FILE"

      if [ $PET_RETRY_COUNT -lt $PET_MAX_RETRIES ]; then
        sleep 10  # Wait longer for transaction retries
      fi
    done

    if [ $PET_EXIT -ne 0 ]; then
      echo "  ❌ Failed to pet after $PET_MAX_RETRIES attempts" >> "$LOG_FILE"
      echo "  Last error: $PET_RESULT" >> "$LOG_FILE"
    fi
  else
    TIME_LEFT=$((REQUIRED_WAIT - TIME_SINCE))
    HOURS=$((TIME_LEFT / 3600))
    MINS=$(((TIME_LEFT % 3600) / 60))
    SECS=$((TIME_LEFT % 60))
    echo "  ⏰ Wait ${HOURS}h ${MINS}m ${SECS}s" >> "$LOG_FILE"
  fi
done

echo "$(date): ✅ Check complete" >> "$LOG_FILE"
