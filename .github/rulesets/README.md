# Branch protection rulesets

Declarative rulesets applied to `main` and `develop` via the GitHub
repository rulesets API. JSON here is the source of truth; the live
rules are managed by `../../scripts/apply-branch-protection.sh`.

## Apply (or update after editing)

```sh
./scripts/apply-branch-protection.sh           # create
./scripts/apply-branch-protection.sh update    # update existing
```

## What these enforce

Both rulesets include the repo admin as a bypass actor (`bypass_mode:
always`). Solo-ship is possible but flagged in the push output.

### `main.json`

- Require pull request; 1 approval; dismiss stale reviews on new commits;
  require approval from whoever made the last push; require conversation
  resolution.
- Required status checks (strict — branch must be up to date):
  `tofu fmt`, `tofu validate`, `tflint`, `trivy config`, `checkov`,
  `gitleaks`, `terraform-docs drift`. These are the job `name:` values
  in `ci.yaml`.
- Block branch deletion.
- Block force push.
- Require linear history (no merge commits — squash only).

### `develop.json`

Same as `main` minus required linear history and require-last-push-approval.

## Updating

If `ci.yaml` gains or renames a job, update the `required_status_checks`
array in both JSON files to match the new `name:` values, then re-run
the apply script with `update`.
