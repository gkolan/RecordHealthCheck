#!/usr/bin/env bash

set -euo pipefail

TARGET_ALIAS="${1:-rhc-demo}"
DURATION_DAYS="${2:-30}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
export SF_DISABLE_LOG_FILE=true
export SFDX_DISABLE_DNS_CHECK=true

if [[ -z "${DEV_HUB_ALIAS:-}" ]]; then
  echo "Set DEV_HUB_ALIAS to your Dev Hub org alias, then re-run." >&2
  echo "Example: DEV_HUB_ALIAS=my-dev-hub ./scripts/setup-demo.sh rhc-demo" >&2
  exit 1
fi

if sf org display --target-org "$TARGET_ALIAS" --json >/dev/null 2>&1; then
  echo "An org already uses alias '$TARGET_ALIAS'. Choose a new alias; this script never overwrites an existing org." >&2
  exit 1
fi

cd "$PROJECT_ROOT"

echo "Creating ${DURATION_DAYS}-day scratch org '$TARGET_ALIAS' with Salesforce sample data..."
sf org create scratch \
  --definition-file config/display-formats-scratch-def.json \
  --alias "$TARGET_ALIAS" \
  --target-dev-hub "$DEV_HUB_ALIAS" \
  --duration-days "$DURATION_DAYS" \
  --wait 30

echo "Deploying Record Health Check core, examples, layouts, and list views..."
sf project deploy start \
  --source-dir force-app \
  --target-org "$TARGET_ALIAS" \
  --wait 30

echo "Configuring the demo administrator as Gautam Kolan..."
sf apex run \
  --target-org "$TARGET_ALIAS" \
  --file scripts/apex/configureDemoAdmin.apex

echo "Installing the demo Account record page..."
sf project deploy start \
  --metadata-dir scripts/demo/metadata \
  --target-org "$TARGET_ALIAS" \
  --wait 30

echo "Assigning the admin permission set..."
sf org assign permset \
  --name Record_Health_Check_Admin \
  --target-org "$TARGET_ALIAS"

echo "Creating or reactivating demo owner Jordan Blake..."
sf apex run \
  --target-org "$TARGET_ALIAS" \
  --file scripts/apex/setupDemoUser.apex

echo "Creating the deterministic Account relationship and risk scenario..."
sf apex run \
  --target-org "$TARGET_ALIAS" \
  --file scripts/apex/setupDemoData.apex

echo "Creating the realistic Account, Contact, and Opportunity example portfolio..."
sf data create record \
  --target-org "$TARGET_ALIAS" \
  --sobject CurrencyType \
  --values "IsoCode=EUR ConversionRate=1.15 DecimalPlaces=2 IsActive=true" \
  --json
sf apex run \
  --target-org "$TARGET_ALIAS" \
  --file scripts/apex/setupExampleData.apex

echo "Deactivating Jordan Blake after Account ownership is assigned..."
sf apex run \
  --target-org "$TARGET_ALIAS" \
  --file scripts/apex/deactivateDemoUser.apex

echo "Generating a manual-login password..."
sf org generate password --target-org "$TARGET_ALIAS"

echo "Validating deployed RHC metadata..."
sf apex run \
  --target-org "$TARGET_ALIAS" \
  --file scripts/apex/validateMetadata.apex

echo "Verifying exact demo data and the 3 pass / 4 fail / 1 skip outcome..."
sf apex run \
  --target-org "$TARGET_ALIAS" \
  --file scripts/apex/verifyDemo.apex

echo "Verifying the realistic example portfolio and object-specific outcomes..."
sf apex run \
  --target-org "$TARGET_ALIAS" \
  --file scripts/apex/verifyExampleData.apex

echo
echo "Record Health Check demo org is ready."
echo "Alias: $TARGET_ALIAS"
echo "Open Accounts: sf org open --target-org $TARGET_ALIAS --path 'lightning/o/Account/list?filterName=AllAccounts'"
