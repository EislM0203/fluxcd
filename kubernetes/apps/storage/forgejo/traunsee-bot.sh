#!/usr/bin/env bash
# Grant the AI bot account (traunsee-bot) access to traunseenet-lab repos and
# lock down main + tags on them to the "maintainers" team. Idempotent: rerun with
# a new repo name to add it.
#
#   FORGEJO_TOKEN=<your token: write:organization,write:repository> ./traunsee-bot.sh fin track mdmem
#   FORK_MODE=1 ... -> bot team gets read-only (bot works from its own forks)
#   NO_BOT=1 ...    -> protection only, the bot gets no access (e.g. dsh, the bot's own image)
#
# What it does:
#   - team "maintainers" (write on all org repos, no settings/admin), OWNER as member;
#     new maintainers = add them to this team in the UI, no rule changes needed
#   - team "agents" (write on code/issues/PRs, or read with FORK_MODE=1; no
#     settings/admin, no wiki/packages/releases write), bot as its only member,
#     only the repos given as arguments
#   - main: only maintainers push and merge, 1 approval from a maintainer required,
#     stale approvals dismissed, rejected review blocks; existing status checks kept
#     plus GUARD (ci / vault-guard (pull_request)) required.
#     apply_to_admins=false: org owners / site admins can still force-merge.
#   - tags: only maintainers may create tags (a v* tag runs the release build)
#
# The bot user and its token are created by hand (secrets), see the end of this file.
set -euo pipefail

URL=${FORGEJO_URL:-https://git.cloud.traunseenet.com}
ORG=${ORG:-traunseenet-lab}
BOT=${BOT:-traunsee-bot}
TEAM=${TEAM:-agents}
MAINT=${MAINT:-maintainers}
OWNER=${OWNER:-markuseisl}
GUARD=${GUARD-ci / vault-guard (pull_request)}
: "${FORGEJO_TOKEN:?set FORGEJO_TOKEN (your own token, write:organization + write:repository)}"
[ $# -gt 0 ] || { echo "usage: $0 <repo>..." >&2; exit 1; }

api() { # api METHOD PATH [JSON]
  curl -sS --fail-with-body -X "$1" -H "Authorization: token $FORGEJO_TOKEN" \
    -H "Content-Type: application/json" "$URL/api/v1$2" ${3:+-d "$3"}
}
status() { curl -s -o /dev/null -w '%{http_code}' -H "Authorization: token $FORGEJO_TOKEN" "$URL/api/v1$1"; }

ensure_team() { # ensure_team NAME DESCRIPTION ALL_REPOS UNITS_JSON -> prints id
  local id body
  id=$(api GET "/orgs/$ORG/teams?limit=50" | jq -r --arg t "$1" '.[] | select(.name==$t) | .id')
  body=$(jq -nc --arg t "$1" --arg d "$2" --argjson all "$3" --argjson u "$4" '{name: $t,
    description: $d, includes_all_repositories: $all, can_create_org_repo: false, units_map: $u}')
  if [ -z "$id" ]; then
    id=$(api POST "/orgs/$ORG/teams" "$body" | jq -r .id)
    echo "team $1 created (id $id)" >&2
  else
    api PATCH "/teams/$id" "$body" >/dev/null
    echo "team $1 updated (id $id)" >&2
  fi
  echo "$id"
}

maint_units='{"repo.code": "write", "repo.issues": "write", "repo.pulls": "write",
  "repo.actions": "write", "repo.releases": "write", "repo.wiki": "write",
  "repo.projects": "write", "repo.packages": "none", "repo.ext_issues": "none", "repo.ext_wiki": "none"}'
maint_id=$(ensure_team "$MAINT" "Push/merge/approve/tag on protected branches, managed by traunsee-bot.sh" true "$maint_units")
api PUT "/teams/$maint_id/members/$OWNER" >/dev/null
echo "$OWNER is member of $MAINT"

if [ "${FORK_MODE:-0}" = 1 ]; then code=read; work=read; else code=write; work=write; fi
bot_units=$(jq -nc --arg c "$code" --arg w "$work" '{
  "repo.code": $c, "repo.issues": $w, "repo.pulls": $w, "repo.actions": "read",
  "repo.releases": "read", "repo.wiki": "none", "repo.packages": "none",
  "repo.projects": "none", "repo.ext_issues": "none", "repo.ext_wiki": "none"}')
team_id=$(ensure_team "$TEAM" "AI agents ($BOT), managed by traunsee-bot.sh" false "$bot_units")
api PUT "/teams/$team_id/members/$BOT" >/dev/null
echo "$BOT is member of $TEAM (code=$code)"

main_rule=$(jq -nc --arg m "$MAINT" '{
  enable_push: true, enable_push_whitelist: true, push_whitelist_teams: [$m], push_whitelist_usernames: [],
  enable_merge_whitelist: true, merge_whitelist_teams: [$m], merge_whitelist_usernames: [],
  required_approvals: 1, enable_approvals_whitelist: true,
  approvals_whitelist_teams: [$m], approvals_whitelist_username: [],
  dismiss_stale_approvals: true, block_on_rejected_reviews: true, apply_to_admins: false}')
tag_rule=$(jq -nc --arg m "$MAINT" '{name_pattern: "*", whitelist_teams: [$m], whitelist_usernames: []}')

for repo in "$@"; do
  echo "== $ORG/$repo"
  if [ "${NO_BOT:-0}" = 1 ]; then
    echo "  $TEAM access: skipped (NO_BOT=1)"
  else
    api PUT "/teams/$team_id/repos/$ORG/$repo" >/dev/null
    echo "  $TEAM access: ok"
  fi

  # Existing required checks are kept; GUARD (PRs can't merge unless Vault refused
  # their identity) is added. Set GUARD= to skip, e.g. for a repo without that job.
  if [ "$(status "/repos/$ORG/$repo/branch_protections/main")" = 200 ]; then
    checks=$(api GET "/repos/$ORG/$repo/branch_protections/main" | jq -c '.status_check_contexts // []')
  else
    api POST "/repos/$ORG/$repo/branch_protections" '{"rule_name": "main"}' >/dev/null
    checks='[]'
  fi
  checks=$(jq -c --arg g "$GUARD" 'if $g == "" then . else (. + [$g] | unique) end' <<<"$checks")
  api PATCH "/repos/$ORG/$repo/branch_protections/main" \
    "$(jq -c --argjson c "$checks" '. + {enable_status_check: ($c | length > 0), status_check_contexts: $c}' <<<"$main_rule")" >/dev/null
  echo "  main protection: ok, required checks: $checks"

  tag_id=$(api GET "/repos/$ORG/$repo/tag_protections" | jq -r '.[] | select(.name_pattern=="*") | .id')
  if [ -z "$tag_id" ]; then
    api POST "/repos/$ORG/$repo/tag_protections" "$tag_rule" >/dev/null
    echo "  tag protection: created"
  else
    api PATCH "/repos/$ORG/$repo/tag_protections/$tag_id" "$tag_rule" >/dev/null
    echo "  tag protection: updated"
  fi
done

# --- one-time, by hand (prints secrets; run it yourself) ---------------------
# kubectl -n storage exec deploy/forgejo -c forgejo -- forgejo admin user create \
#   --username traunsee-bot --fullname "traunsee-bot (AI agent)" \
#   --email traunsee-bot@noreply.git.cloud.traunseenet.com \
#   --random-password --must-change-password=false --restricted
# kubectl -n storage exec deploy/forgejo -c forgejo -- forgejo admin user generate-access-token \
#   --username traunsee-bot --token-name deepseek-harness --raw \
#   --scopes write:repository,write:issue,read:user,read:organization
# Then on the harness machine store the token in fj (see `fj auth --help`, e.g.
# `fj -H git.cloud.traunseenet.com auth add-key traunsee-bot`) and set git
# user.name/user.email to the bot in the harness's checkouts.
