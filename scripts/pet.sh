#\!/bin/bash
set -e

# Load config
SKILL_DIR="$HOME/.openclaw/skills/aavegotchi"
CONFIG_FILE="$SKILL_DIR/config.json"

if [ \! -f "$CONFIG_FILE" ]; then
  echo "Error: Config file not found at $CONFIG_FILE"
  exit 1
fi

# Parse config
CONTRACT=$(jq -r .contractAddress "$CONFIG_FILE")
GOTCHI_ID=${1:-$(jq -r .gotchiId "$CONFIG_FILE")}
RPC_URL=$(jq -r .rpcUrl "$CONFIG_FILE")
PRIVATE_KEY=$(jq -r .privateKey "$CONFIG_FILE")

if [ "$PRIVATE_KEY" = "YOUR_PRIVATE_KEY_HERE" ] || [ -z "$PRIVATE_KEY" ]; then
  echo "Error: Private key not configured"
  exit 1
fi

echo "Petting Aavegotchi #$GOTCHI_ID..."

# Call interact function with gotchi ID
export PATH="$HOME/.foundry/bin:$PATH"
cast send "$CONTRACT" \
  "interact(uint256[])" \
  "[$GOTCHI_ID]" \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY"

echo "✅ Aavegotchi #$GOTCHI_ID petted successfully\!"
