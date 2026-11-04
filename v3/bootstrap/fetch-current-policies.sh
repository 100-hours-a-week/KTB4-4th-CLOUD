#!/usr/bin/env bash
set -euo pipefail
PROFILE="${AWS_PROFILE:-needu-v2}"
ROLE="NeedU-V3-Terraform-Dev"
mkdir -p policies
aws iam get-role --role-name "$ROLE" --profile "$PROFILE" --query 'Role.AssumeRolePolicyDocument' --output json > policies/trust.json
for policy in TerraformV3Apply TerraformV3ResourceRead TerraformV3State; do
  aws iam get-role-policy --role-name "$ROLE" --policy-name "$policy" --profile "$PROFILE" --query PolicyDocument --output json > "policies/$policy.json"
done
python3 - <<'PY'
import json, pathlib
for f in pathlib.Path('policies').glob('*.json'):
    data=json.loads(f.read_text())
    if not isinstance(data,dict) or 'Statement' not in data:
        raise SystemExit(f'Invalid IAM document: {f}')
    f.write_text(json.dumps(data,indent=2,ensure_ascii=False)+'\n')
    print('Fetched:',f)
PY
