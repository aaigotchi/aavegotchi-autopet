#\!/bin/bash
set -e

export PATH="$HOME/.foundry/bin:$PATH"

CONFIG_FILE="$HOME/.openclaw/skills/aavegotchi/config.json"

# Load private key (NO PASSWORD NEEDED)
PRIVATE_KEY=$(gpg --quiet --decrypt ~/.openclaw/secrets/aavegotchi-private-key.gpg 2>/dev/null)

if [ -z "$PRIVATE_KEY" ]; then
  echo "❌ No private key found. Add with:"
  echo "   echo '0xYourKey' | gpg --encrypt --recipient automation@openclaw.local -o ~/.openclaw/secrets/aavegotchi-private-key.gpg"
  exit 1
fi

# Load config
CONTRACT=$(jq -r ".contractAddress" "$CONFIG_FILE")
RPC_URL=$(jq -r ".rpcUrl" "$CONFIG_FILE")

# Get gotchi ID from argument or config
if [ -n "$1" ]; then
  GOTCHI_ID="$1"
  echo "🦞 Petting Gotchi #$GOTCHI_ID (manual)..."
else
  # Pet all gotchis from config
  GOTCHI_IDS=$(jq -r ".gotchiIds[]" "$CONFIG_FILE")
  
  for GOTCHI_ID in $GOTCHI_IDS; do
    echo "🦞 Petting Gotchi #$GOTCHI_ID..."
    
    cast send "$CONTRACT" \
      "interact(uint256[])" \
      "[$GOTCHI_ID]" \
      --rpc-url "$RPC_URL" \
      --private-key "$PRIVATE_KEY"
    
    echo "✅ Gotchi #$GOTCHI_ID petted\!"
  done
  
  exit 0
fi

# Pet single gotchi (from argument)
cast send "$CONTRACT" \
  "interact(uint256[])" \
  "[$GOTCHI_ID]" \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY"

echo "✅ Gotchi #$GOTCHI_ID petted\!"
