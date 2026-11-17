#!/usr/bin/env bash
# Exercises claude-account in a throwaway HOME with a fake `claude` that reports how it was launched.
# PATH is cut down to the system directories, so on macOS the script runs under the stock bash 3.2.

SCRIPT="$(cd -P "$(dirname "$0")" && pwd -P)/claude-account"
T=$(mktemp -d "${TMPDIR:-/tmp}/claude-account-test.XXXXXX")
T=$(cd -P "$T" && pwd -P)
trap 'rm -rf "$T"' EXIT

export HOME="$T/home"
FAKEBIN="$T/fakebin"
export PATH="$HOME/.claude-accounts/bin:$FAKEBIN:/usr/bin:/bin:/usr/sbin:/sbin"
unset CLAUDE_ACCOUNT CLAUDE_ACCOUNT_ACTIVE CLAUDE_CONFIG_DIR CLAUDE_ACCOUNT_REAL_CLAUDE CDPATH

PASS=0
FAIL=0
check() {
  if [ "$3" = "$2" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL %s\n  expected: %s\n  actual:   %s\n' "$1" "$2" "$3"
  fi
}
contains() {
  case $3 in
    *"$2"*) PASS=$((PASS + 1)) ;;
    *) FAIL=$((FAIL + 1)); printf 'FAIL %s\n  expected to contain: %s\n  actual: %s\n' "$1" "$2" "$3" ;;
  esac
}
encode() { printf '%s' "${1//[^a-zA-Z0-9]/-}"; }

mkdir -p "$FAKEBIN" "$HOME/.claude/skills/demo" "$HOME/.claude/plugins" "$T/nix"
cat > "$FAKEBIN/claude" <<'EOF'
#!/bin/bash
printf 'dir=%s active=%s args=' "${CLAUDE_CONFIG_DIR-unset}" "$CLAUDE_ACCOUNT_ACTIVE"
[ $# -gt 0 ] && printf '[%s]' "$@"
printf '\n'
EOF
chmod +x "$FAKEBIN/claude"

echo '{"statusLine":{}}' > "$T/nix/settings.json"
ln -s "$T/nix/settings.json" "$HOME/.claude/settings.json"
echo '@RTK.md' > "$HOME/.claude/CLAUDE.md"
echo 'rtk' > "$HOME/.claude/RTK.md"

P="$HOME/Projects"
mkdir -p "$P/work_apps/app1/sub" "$P/work_apps/playground" "$P/work_apps2" "$P/Space Dir/proj" "$P/personal" "$P/memonly"
ln -s "$P/work_apps/app1" "$HOME/linked"

cat > "$HOME/.claude.json" <<EOF
{
  "numStartups": 5,
  "userID": "abc",
  "oauthAccount": { "emailAddress": "work@corp.example", "organizationName": "Corp" },
  "cachedGrowthBookFeatures": { "x": 1 },
  "mcpServers": { "rea": { "command": "npx" } },
  "projects": { "$P/memonly": { "allowedTools": [] } }
}
EOF

# install and add
out=$("$SCRIPT" install 2>&1)
contains "install reports location" "Installed into" "$out"
check "claude link" "$SCRIPT" "$(readlink "$HOME/.claude-accounts/bin/claude")"
check "claude-account link" "$SCRIPT" "$(readlink "$HOME/.claude-accounts/bin/claude-account")"
check "default account" "personal" "$(cat "$HOME/.claude-accounts/default")"

out=$(claude-account add work --no-login 2>&1)
contains "add reports creation" "Created account work" "$out"
W="$HOME/.claude-accounts/work"
check "settings linked" "$HOME/.claude/settings.json" "$(readlink "$W/settings.json")"
check "CLAUDE.md linked" "$HOME/.claude/CLAUDE.md" "$(readlink "$W/CLAUDE.md")"
check "RTK.md linked" "$HOME/.claude/RTK.md" "$(readlink "$W/RTK.md")"
check "skills linked" "$HOME/.claude/skills" "$(readlink "$W/skills")"
check "plugins linked" "$HOME/.claude/plugins" "$(readlink "$W/plugins")"
check "settings readable through links" '{"statusLine":{}}' "$(cat "$W/settings.json")"
seeded=$(cat "$W/.claude.json")
contains "seed keeps MCP servers" '"rea"' "$seeded"
contains "seed keeps projects" "$P/memonly" "$seeded"
contains "seed keeps counters" '"numStartups": 5' "$seeded"
check "seed drops login" "" "$(printf '%s' "$seeded" | grep -E 'oauthAccount|emailAddress|userID')"
check "seed drops caches" "" "$(printf '%s' "$seeded" | grep cachedGrowthBook)"
check "seed is private" "-rw-------" "$(ls -l "$W/.claude.json" | cut -c1-10)"
out=$(claude-account add work --no-login 2>&1)
contains "add refuses duplicates" "already exists" "$out"
out=$(claude-account add Bad --no-login 2>&1)
contains "add rejects bad names" "account names use" "$out"

# rules
claude-account rule "$P/work_apps" work >/dev/null
claude-account rule "$P/work_apps/playground" personal >/dev/null
claude-account rule "$P/Space Dir" work >/dev/null
out=$(claude-account rule "$P/x" nobody 2>&1)
contains "rule rejects unknown account" "unknown account 'nobody'" "$out"

launch() { (cd "$1" && shift && claude "$@"); }
check "unmatched folder uses default" "dir=unset active=personal args=" "$(launch "$P/personal")"
check "rule folder" "dir=$W active=work args=" "$(launch "$P/work_apps")"
check "beneath rule folder" "dir=$W active=work args=" "$(launch "$P/work_apps/app1/sub")"
check "sibling with shared prefix" "dir=unset active=personal args=" "$(launch "$P/work_apps2")"
check "deepest rule wins" "dir=unset active=personal args=" "$(launch "$P/work_apps/playground")"
check "folder with spaces" "dir=$W active=work args=" "$(launch "$P/Space Dir/proj")"
check "symlinked folder resolves" "dir=$W active=work args=" "$(launch "$HOME/linked")"
check "arguments pass through" "dir=$W active=work args=[-p][two words][]" "$(launch "$P/work_apps" -p "two words" "")"
check "stray CLAUDE_CONFIG_DIR cleared" "dir=unset active=personal args=" "$(cd "$P/personal" && CLAUDE_CONFIG_DIR=/x claude)"

# precedence
check "override" "dir=$W active=work args=" "$(cd "$P/personal" && CLAUDE_ACCOUNT=work claude)"
check "inherited" "dir=$W active=work args=" "$(cd "$P/personal" && CLAUDE_ACCOUNT_ACTIVE=work claude)"
check "override beats inherited" "dir=unset active=personal args=" \
  "$(cd "$P/work_apps" && CLAUDE_ACCOUNT=personal CLAUDE_ACCOUNT_ACTIVE=work claude)"
check "stale inherited account ignored" "dir=$W active=work args=" "$(cd "$P/work_apps" && CLAUDE_ACCOUNT_ACTIVE=gone claude)"
out=$(cd "$P/personal" && CLAUDE_ACCOUNT=wrok claude 2>&1)
code=$?
contains "unknown override explains" "unknown account 'wrok'" "$out"
check "unknown override fails" "1" "$code"

# which, list, unrule
contains "which names the rule" "work (Folder Rule for ~/Projects/work_apps)" "$(claude-account which "$P/work_apps/app1")"
contains "which names the default" "personal (no Folder Rule" "$(claude-account which "$P/personal")"
contains "which reports override" "Override" "$(CLAUDE_ACCOUNT=work claude-account which "$P/personal")"
contains "which reports inherited" "Inherited" "$(CLAUDE_ACCOUNT_ACTIVE=work claude-account which "$P/personal")"
out=$(claude-account list)
contains "list shows rule" "~/Projects/Space Dir -> work" "$out"
contains "list shows default email" "work@corp.example" "$out"
claude-account rule "$P/work_apps" personal >/dev/null
check "rule replaces existing" "1" "$(grep -c "work_apps	" "$HOME/.claude-accounts/rules")"
claude-account rule "$P/work_apps" work >/dev/null
claude-account unrule "$P/Space Dir" >/dev/null
check "unrule" "dir=unset active=personal args=" "$(launch "$P/Space Dir/proj")"
out=$(claude-account unrule "$P/Space Dir" 2>&1)
contains "unrule of a missing rule fails" "no Folder Rule" "$out"

# status
check "status default" "Personal - work@corp.example" "$(claude-account status)"
check "status before login" "Work - not logged in" "$(CLAUDE_CONFIG_DIR="$W" claude-account status)"
printf '{\n  "oauthAccount": {\n    "emailAddress": "me@work.example"\n  }\n}\n' > "$W/.claude.json"
check "status after login" "Work - me@work.example" "$(CLAUDE_CONFIG_DIR="$W" claude-account status)"

# migrate
PR="$HOME/.claude/projects"
A1=$(encode "$P/work_apps/app1")
PG=$(encode "$P/work_apps/playground")
MO=$(encode "$P/memonly")
CF=$(encode "$P/work_apps/app1/sub")
mkdir -p "$PR/$A1/sess" "$PR/$PG" "$PR/-unknown-thing/memory" "$PR/$CF" "$W/projects/$CF"
cat > "$PR/$A1/sessions-index.json" <<EOF
{ "entries": [ { "fullPath": "$PR/$A1/s1.jsonl", "projectPath": "$P/work_apps/app1" } ] }
EOF
echo '{"cwd":"x"}' > "$PR/$A1/s1.jsonl"
echo '{"type":"summary"}' > "$PR/$PG/s.jsonl"
echo "{\"cwd\":\"$P/work_apps/playground\"}" >> "$PR/$PG/s.jsonl"
echo "{\"cwd\":\"$P/work_apps/app1/sub\"}" > "$PR/$CF/s.jsonl"
mkdir -p "$PR/$MO/memory"
claude-account rule "$P/memonly" work >/dev/null

out=$(claude-account migrate)
contains "dry run lists move" "~/Projects/work_apps/app1: personal -> work" "$out"
contains "dry run finds path via state file" "~/Projects/memonly: personal -> work" "$out"
contains "dry run reports conflict" "already has history" "$out"
contains "dry run reports unknown" "? -unknown-thing" "$out"
contains "dry run says so" "This was a dry run" "$out"
check "dry run moves nothing" "yes" "$([ -d "$PR/$A1" ] && echo yes)"

out=$(claude-account migrate --apply)
contains "apply summary" "2 project(s) moved" "$out"
check "moved to work" "yes" "$([ -f "$W/projects/$A1/s1.jsonl" ] && [ ! -e "$PR/$A1" ] && echo yes)"
check "memory moved" "yes" "$([ -d "$W/projects/$MO/memory" ] && echo yes)"
contains "index repointed" "\"fullPath\": \"$W/projects/$A1/s1.jsonl\"" "$(cat "$W/projects/$A1/sessions-index.json")"
check "personal project stays" "yes" "$([ -d "$PR/$PG" ] && echo yes)"
check "conflict left in place" "yes" "$([ -d "$PR/$CF" ] && echo yes)"
check "unknown left in place" "yes" "$([ -d "$PR/-unknown-thing" ] && echo yes)"
contains "second run is a no-op" "0 project(s)" "$(claude-account migrate)"

claude-account rule "$P/work_apps" personal >/dev/null
claude-account migrate --apply >/dev/null
check "migrate works in reverse" "yes" "$([ -f "$PR/$A1/s1.jsonl" ] && echo yes)"
contains "reverse repoints index" "\"fullPath\": \"$PR/$A1/s1.jsonl\"" "$(cat "$PR/$A1/sessions-index.json")"
claude-account rule "$P/work_apps" work >/dev/null

# doctor
out=$(claude-account doctor)
code=$?
contains "doctor sees wrapper" "ok  claude on PATH is the wrapper" "$out"
contains "doctor sees login" "ok  work: me@work.example" "$out"
contains "doctor reports MCP drift" "MCP server rea exists for personal but not work" "$out"
check "doctor passes" "0" "$code"
rm "$W/skills"
out=$(claude-account doctor)
check "doctor fails on missing link" "1" "$?"
contains "doctor names missing link" "skills is not linked" "$out"
claude-account doctor --fix >/dev/null
check "doctor --fix relinks" "$HOME/.claude/skills" "$(readlink "$W/skills")"
mkdir "$HOME/.claude/commands"
contains "doctor --fix links new Setup items" "linked commands" "$(claude-account doctor --fix)"

# every JSON backend present on this machine
for tool in osascript python3 jq; do
  command -v "$tool" >/dev/null 2>&1 || continue
  [ "$tool" = python3 ] && ! python3 -c pass >/dev/null 2>&1 && continue
  CLAUDE_ACCOUNT_JSON_TOOL=$tool claude-account add "via$tool" --no-login >/dev/null 2>&1
  seeded=$(cat "$HOME/.claude-accounts/via$tool/.claude.json" 2>/dev/null)
  contains "$tool seed keeps MCP servers" '"rea"' "$seeded"
  contains "$tool seed keeps projects" "$P/memonly" "$seeded"
  check "$tool seed drops login and caches" "" "$(printf '%s' "$seeded" | grep -E 'oauthAccount|userID|cachedGrowthBook')"
  contains "$tool reads MCP servers" "MCP server rea exists for personal but not work" \
    "$(CLAUDE_ACCOUNT_JSON_TOOL=$tool claude-account doctor)"
  rm -rf "$HOME/.claude-accounts/via$tool"
done

# no real claude
out=$(cd "$P/personal" && PATH="$HOME/.claude-accounts/bin:/usr/bin:/bin" claude 2>&1)
contains "missing real claude explains" "cannot find the real claude" "$out"

# uninstall
out=$(claude-account uninstall)
contains "uninstall reports leftovers" "Account work is still in" "$out"
check "uninstall removes the wrapper" "" "$(ls "$HOME/.claude-accounts/bin" 2>/dev/null)"
check "uninstall keeps accounts" "yes" "$([ -d "$W/projects" ] && echo yes)"

printf '\n%s passed, %s failed (bash %s)\n' "$PASS" "$FAIL" "$BASH_VERSION"
[ "$FAIL" = 0 ]
