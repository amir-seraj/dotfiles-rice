#!/usr/bin/env bash
# Backend for the qs-github-lab popup. Emits JSON on stdout.
# Usage:
#   gh_data.sh <subcommand>            # use cache if fresh, else fetch
#   gh_data.sh --no-cache <subcommand> # always fetch
#   gh_data.sh --prefetch-all          # warm every cache entry, no stdout output
#
# Subcommands: profile pulls reviews issues notifications repos starred gists activity workflows
set -euo pipefail

CACHE_DIR="$HOME/.cache/qs-github-lab"
TTL_SECONDS=120
mkdir -p "$CACHE_DIR"

NO_CACHE=0
if [[ "${1:-}" == "--no-cache" ]]; then NO_CACHE=1; shift; fi

CMD="${1:-profile}"

# ---- helpers ----
_fresh() {
    # $1 = path; returns 0 if file is younger than TTL
    [[ -s "$1" ]] || return 1
    local age; age=$(( $(date +%s) - $(stat -c %Y "$1") ))
    (( age < TTL_SECONDS ))
}
_count() {
    local out; out="$(eval "$1" 2>/dev/null | jq 'length // 0' 2>/dev/null)"
    echo "${out:-0}"
}
_save_and_print() {
    # $1 = cache file path; reads stdin once, writes to cache atomically AND prints to stdout.
    # Synchronous (unlike `tee >(_emit ...)`) so the cache is guaranteed present on exit.
    local cache="$1"
    local tmp; tmp="$(mktemp)"
    cat > "$tmp"
    if jq -e . "$tmp" >/dev/null 2>&1; then
        mv "$tmp" "$cache"
        cat "$cache"
    else
        cat "$tmp"
        rm -f "$tmp"
    fi
}

# ---- gh sanity ----
if ! command -v gh >/dev/null; then
    printf '{"error":"gh CLI not installed"}\n'; exit 0
fi
if ! gh auth status >/dev/null 2>&1; then
    printf '{"error":"gh not authenticated. Run: gh auth login"}\n'; exit 0
fi

# ---- prefetch mode (no stdout) ----
if [[ "$CMD" == "--prefetch-all" ]]; then
    for c in profile pulls reviews issues notifications repos starred gists activity workflows; do
        "$0" --no-cache "$c" >/dev/null 2>&1 || true
    done
    exit 0
fi

# ---- normal path: serve from cache if fresh ----
CACHE_FILE="$CACHE_DIR/$CMD.json"
if [[ $NO_CACHE -eq 0 ]] && _fresh "$CACHE_FILE"; then
    cat "$CACHE_FILE"
    exit 0
fi

# ---- fetch ----
case "$CMD" in
    profile)
        USER_JSON="$(gh api /user 2>/dev/null || echo '{}')"
        LOGIN="$(echo "$USER_JSON" | jq -r '.login // "anon"')"
        PRS_OPEN="$(_count "gh search prs --author=@me --state=open --json number")"
        ISSUES_OPEN="$(_count "gh search issues --assignee=@me --state=open --type=issue --json number")"
        REVIEW_REQ="$(_count "gh search prs --review-requested=@me --state=open --json number")"
        NOTIFS="$(_count "gh api /notifications --paginate=false")"
        STARS_GIVEN="$(gh api "/users/$LOGIN/starred?per_page=1" -i 2>/dev/null | grep -i '^link:' | grep -oE 'page=[0-9]+' | tail -1 | grep -oE '[0-9]+' || true)"
        # special profile README at github.com/<login>/<login>; absent → empty string
        # convert ![alt](url) → alt so shields.io / stats badges become readable text
        # instead of broken-image icons in Qt's MarkdownText renderer.
        README_MD="$(
            gh api "/repos/$LOGIN/$LOGIN/readme" --jq .content 2>/dev/null \
                | base64 -d 2>/dev/null \
                | sed -E 's/!\[([^]]*)\]\([^)]*\)/\1/g' \
                || true
        )"
        echo "$USER_JSON" | jq --argjson pr "${PRS_OPEN:-0}" --argjson iss "${ISSUES_OPEN:-0}" --argjson rev "${REVIEW_REQ:-0}" --argjson nt "${NOTIFS:-0}" --argjson sg "${STARS_GIVEN:-0}" --arg rm "$README_MD" '{
            type: "profile",
            login: (.login // "anon"),
            name, avatar_url, html_url, bio, location, blog, company,
            public_repos, public_gists, followers, following, created_at,
            profile_readme: $rm,
            stats: { open_prs:$pr, open_issues:$iss, review_requested:$rev, notifications:$nt, stars_given:$sg }
        }' | _save_and_print "$CACHE_FILE"
        ;;
    pulls)
        gh search prs --author=@me --state=open -L 30 \
            --json number,title,url,state,repository,createdAt,updatedAt,isDraft 2>/dev/null \
            | jq '{type:"pulls", items: (. // [])}' | _save_and_print "$CACHE_FILE"
        ;;
    reviews)
        gh search prs --review-requested=@me --state=open -L 30 \
            --json number,title,url,repository,author,createdAt,updatedAt 2>/dev/null \
            | jq '{type:"reviews", items: (. // [])}' | _save_and_print "$CACHE_FILE"
        ;;
    issues)
        gh search issues --assignee=@me --state=open --type=issue -L 30 \
            --json number,title,url,repository,createdAt,updatedAt 2>/dev/null \
            | jq '{type:"issues", items: (. // [])}' | _save_and_print "$CACHE_FILE"
        ;;
    notifications)
        gh api /notifications --paginate=false 2>/dev/null \
            | jq '{type:"notifications", items: (. // [] | map({
                    reason, unread, updated_at,
                    title: .subject.title, subject_type: .subject.type,
                    repo: .repository.full_name, api_url: .subject.url
                  }))}' | _save_and_print "$CACHE_FILE"
        ;;
    repos)
        gh repo list --limit 30 \
            --json name,nameWithOwner,description,url,stargazerCount,forkCount,primaryLanguage,visibility,updatedAt 2>/dev/null \
            | jq '{type:"repos", items: (. // [])}' | _save_and_print "$CACHE_FILE"
        ;;
    starred)
        LOGIN="$(gh api /user --jq .login 2>/dev/null)"
        gh api "/users/$LOGIN/starred?per_page=30" 2>/dev/null \
            | jq '{type:"starred", items: (. // [] | map({
                    full_name, html_url, description, stargazers_count, forks_count, language, updated_at
                  }))}' | _save_and_print "$CACHE_FILE"
        ;;
    gists)
        gh gist list -L 30 2>/dev/null \
            | awk -F'\t' 'BEGIN{print "["} NR>1{printf ","}{
                gsub(/"/, "\\\"", $2);
                printf "{\"id\":\"%s\",\"description\":\"%s\",\"files\":\"%s\",\"public\":\"%s\",\"updated\":\"%s\"}", $1, $2, $3, $4, $5
              } END{print "]"}' \
            | jq '{type:"gists", items: (. // [])}' | _save_and_print "$CACHE_FILE"
        ;;
    activity)
        LOGIN="$(gh api /user --jq .login 2>/dev/null)"
        gh api "/users/$LOGIN/events?per_page=30" 2>/dev/null \
            | jq '{type:"activity", items: (. // [] | map({
                    type, repo: .repo.name, created_at,
                    summary: (
                        if .type == "PushEvent" then ("pushed " + ((.payload.commits // []) | length | tostring) + " commits to " + (.payload.ref // ""))
                        elif .type == "PullRequestEvent" then (.payload.action + " PR #" + (.payload.number|tostring) + ": " + (.payload.pull_request.title // ""))
                        elif .type == "IssuesEvent" then (.payload.action + " issue #" + (.payload.issue.number|tostring) + ": " + (.payload.issue.title // ""))
                        elif .type == "WatchEvent" then "starred"
                        elif .type == "ForkEvent" then ("forked → " + (.payload.forkee.full_name // ""))
                        elif .type == "CreateEvent" then ("created " + (.payload.ref_type // "") + " " + (.payload.ref // ""))
                        elif .type == "DeleteEvent" then ("deleted " + (.payload.ref_type // "") + " " + (.payload.ref // ""))
                        elif .type == "IssueCommentEvent" then ("commented on issue #" + (.payload.issue.number|tostring))
                        elif .type == "PullRequestReviewEvent" then ("reviewed PR #" + (.payload.pull_request.number|tostring))
                        elif .type == "PullRequestReviewCommentEvent" then ("commented on review")
                        else (.type | sub("Event$"; "")) end
                    ),
                    url: ("https://github.com/" + .repo.name)
                  }))}' | _save_and_print "$CACHE_FILE"
        ;;
    workflows)
        LOGIN="$(gh api /user --jq .login 2>/dev/null)"
        REPOS="$(gh api "/users/$LOGIN/repos?type=owner&sort=updated&per_page=6" --jq '.[].full_name' 2>/dev/null)"
        {
            printf '{"type":"workflows","items":['
            first=1
            while IFS= read -r repo; do
                [[ -z "$repo" ]] && continue
                runs="$(gh api "/repos/$repo/actions/runs?per_page=5" --jq '.workflow_runs // []' 2>/dev/null || echo '[]')"
                count="$(echo "$runs" | jq 'length')"
                for i in $(seq 0 $((count-1))); do
                    [[ $first -eq 0 ]] && printf ','
                    first=0
                    echo "$runs" | jq --arg r "$repo" ".[$i] | {repo:\$r, name, status, conclusion, html_url, run_number, head_branch, updated_at}"
                done
            done <<< "$REPOS"
            printf ']}'
        } | _save_and_print "$CACHE_FILE"
        ;;
    *)
        printf '{"error":"unknown subcommand: %s"}\n' "$CMD"
        ;;
esac
