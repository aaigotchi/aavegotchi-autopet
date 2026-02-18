# Optional Integration: Coinbase CDP Server Wallet (No `privateKey` in `.env`)

This guide is an optional security path for this repo.

Important:
- Current shell scripts in this repo still use private-key-path signing today.
- This document shows how to integrate CDP by swapping only the signing backend in a wrapper worker.
- Cooldown logic and gotchi scheduling should remain unchanged.

## Why Use CDP

Threat model improvements:
- No raw private key in `.env`.
- Policy restrictions on where and how transactions can be sent.
- Safer prepare -> execute flow for cron/agent workflows.

References:
- CDP Server Wallet v2 Quickstart: https://docs.cdp.coinbase.com/server-wallets/v2/quickstart
- CDP Policy Engine API: https://docs.cdp.coinbase.com/api-reference/v2/rest-api/policy-engine/create-a-policy
- OpenClaw tool approvals: https://docs.openclaw.ai/tools/exec-approvals

## Prerequisites

- Existing AutoPet workflow working with current scripts.
- Coinbase CDP Server Wallet credentials.
- Base mainnet signer and gas funding.
- `cast` available for calldata/selector verification.

## Secure Credentials Pattern

Use encrypted file path loading instead of environment private keys:

```bash
export CDP_CREDENTIALS_PATH="$HOME/.openclaw/secrets/cdp-autopet.json.gpg"
export CDP_DECRYPT_CMD='gpg --quiet --decrypt'
```

Example decrypted JSON:

```json
{
  "apiKeyId": "cdp_api_key_id",
  "apiKeySecret": "cdp_api_key_secret",
  "walletSecret": "cdp_wallet_secret",
  "networkId": "base-mainnet",
  "accountAddress": "0xYourSignerAddress",
  "policyId": "optional_policy_id"
}
```

## Wallet Bootstrap Paths

### Path A: Import existing EOA

Use this to preserve existing wallet identity and operator permissions.

1. Prepare one-time encrypted export material.
2. Import into CDP Server Wallet.
3. Confirm signer equals current `walletAddress`.

### Path B: Create a new CDP wallet

1. Create signer in CDP.
2. Transfer required gas and ensure operator permissions for target gotchis.
3. Update wrapper worker config with new signer address.

## Policy Allowlist for AutoPet

Allow only:
- Chain: Base mainnet (`8453`).
- Destination: Aavegotchi diamond used by this repo.
- Method: `interact(uint256[])` only.

Selector derivation:

```bash
cast sig "interact(uint256[])"
```

Optional constraints:
- Maximum array length per tx.
- Maximum tx frequency in a time window.

## Wrapper Worker Pattern (Keep Existing Cooldown Logic)

Do not rewrite current cooldown scheduling logic. Instead:

1. Keep `check-and-pet-auto.sh` timing and gotchi selection logic.
2. Replace only the signing/broadcast step with a wrapper worker:
   - Build calldata for `interact([gotchiId])`.
   - Create intent with TTL (example: 300s).
   - Execute intent through CDP signer after confirmation checks.

Pseudo flow:

1. `prepare-intent` receives `gotchiId`, contract, chain.
2. `prepare-intent` emits frozen intent JSON.
3. `execute-intent` submits exactly that intent to CDP.
4. Log tx hash back into existing autopet logs.

Example intent record:

```json
{
  "intentId": "sha256:...",
  "action": "pet_gotchi",
  "chainId": 8453,
  "to": "0xa99c4b08201f2913db8d28e71d020c4298f29dbf",
  "data": "0x...",
  "value": "0x0",
  "gotchiId": "9638",
  "createdAt": "2026-02-18T00:00:00.000Z",
  "expiresAt": "2026-02-18T00:05:00.000Z",
  "status": "prepared"
}
```

## OpenClaw Hardening Checklist

- Keep write/broadcast tools behind explicit execution approvals.
- Validate gotchi IDs and destination contract before intent creation.
- Never execute arbitrary shell from model output.
- Keep read-only checks (cooldown/subgraph/onchain reads) separate from broadcast path.

References:
- https://docs.openclaw.ai/tools
- https://docs.openclaw.ai/sandboxing
- https://docs.openclaw.ai/tools/exec-approvals

## Troubleshooting

- Policy deny: verify method selector and contract allowlist.
- Signer mismatch: check `accountAddress` vs configured wallet/operator permissions.
- Expired intent: regenerate intent and rerun execute.
- Cron failures: preserve existing retry/backoff behavior and log paths.

## Fallback (Current Legacy Flow)

If CDP integration is unavailable, continue using current scripts exactly as documented in `README.md` and `SKILL.md`.

This file is integration guidance only and does not change runtime behavior in this repo.
