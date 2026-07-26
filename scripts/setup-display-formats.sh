#!/usr/bin/env bash

# Creates a scratch org that shows every Display: Value Format option on one card.
#
# Deploys the Framework plus the integration-test fixtures, seeds an Account and
# Opportunity chosen so each format has something to show, then prints the Found
# and Expected chips for every Rule.
#
#   DEV_HUB_ALIAS=my-dev-hub ./scripts/setup-display-formats.sh [alias] [days]

set -euo pipefail

TARGET_ALIAS="${1:-rhc-display-formats}"
DURATION_DAYS="${2:-7}"
# The definition turns on MultiCurrency so the card can show a record keeping its
# own currency. Pass a single-currency definition to see the symbol style instead.
SCRATCH_DEF="${SCRATCH_DEF:-config/display-formats-scratch-def.json}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
export SF_DISABLE_LOG_FILE=true
export SFDX_DISABLE_DNS_CHECK=true

if [[ -z "${DEV_HUB_ALIAS:-}" ]]; then
  echo "Set DEV_HUB_ALIAS to your Dev Hub org alias, then re-run." >&2
  echo "Example: DEV_HUB_ALIAS=my-dev-hub ./scripts/setup-display-formats.sh" >&2
  exit 1
fi

if sf org display --target-org "$TARGET_ALIAS" --json >/dev/null 2>&1; then
  echo "An org already uses alias '$TARGET_ALIAS'. Choose a new alias; this script never overwrites an existing org." >&2
  exit 1
fi

cd "$PROJECT_ROOT"

echo "==> Creating ${DURATION_DAYS}-day scratch org '$TARGET_ALIAS'..."
sf org create scratch \
  --definition-file "$SCRATCH_DEF" \
  --alias "$TARGET_ALIAS" \
  --target-dev-hub "$DEV_HUB_ALIAS" \
  --duration-days "$DURATION_DAYS" \
  --wait 30

echo "==> Deploying the Record Health Check Framework..."
sf project deploy start \
  --source-dir force-app \
  --target-org "$TARGET_ALIAS" \
  --wait 30

echo "==> Deploying the display-format fixture Check Set and Rules..."
# Fixtures live outside the packaged directory and never ship to a customer org.
sf project deploy start \
  --source-dir integration-tests \
  --target-org "$TARGET_ALIAS" \
  --wait 30

echo "==> Assigning the admin permission set..."
sf org assign permset \
  --name Record_Health_Check_Admin \
  --target-org "$TARGET_ALIAS"

# A second active currency makes the per-record currency visible. CurrencyType
# rejects Apex DML, so it is created through the API instead.
if grep -q '"MultiCurrency"' "$SCRATCH_DEF"; then
  echo "==> Activating a second currency (EUR)..."
  sf data create record --target-org "$TARGET_ALIAS" --sobject CurrencyType \
    --values "IsoCode=EUR ConversionRate=0.92 DecimalPlaces=2 IsActive=true" >/dev/null
fi

echo "==> Seeding the Account and Opportunity the Rules read..."
SEED_LOG="$(sf apex run --target-org "$TARGET_ALIAS" --file scripts/apex/setupDisplayFormatData.apex 2>&1)"

# Only USER_DEBUG lines are real output; the log also echoes the script source back.
ACCOUNT_URL="$(printf '%s\n' "$SEED_LOG" |
  grep 'USER_DEBUG' |
  grep -oE 'RHC_DISPLAY_FORMAT_ACCOUNT_URL=.*' |
  sed 's/RHC_DISPLAY_FORMAT_ACCOUNT_URL=//' | tail -1)"

echo "==> Running every Rule and printing the Found and Expected chips..."
echo
sf apex run \
  --target-org "$TARGET_ALIAS" \
  --file scripts/apex/verifyDisplayFormats.apex 2>&1 |
  grep 'USER_DEBUG' |
  grep -oE 'RHC_(FORMAT|DISPLAY_FORMAT_VERIFY).*' |
  sed 's/&#124;/|/g' || true

echo
echo "==> Done. Open the seeded Account to see the card:"
if [[ -n "$ACCOUNT_URL" ]]; then
  echo "    $ACCOUNT_URL"
fi
echo
echo "    sf org open --target-org $TARGET_ALIAS"
echo
echo "The 'Account Display Formats' Check Set covers all nine Display: Value Format"
echo "options. Add the Record Health Check component to the Account record page and"
echo "point it at that Check Set to see them rendered."
