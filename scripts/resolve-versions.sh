#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
plugins_file=${PLUGINS_FILE:-"$repo_root/plugins.txt"}
github_output=${GITHUB_OUTPUT:-}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "error: required command not found: $1" >&2
        exit 1
    }
}

require_cmd curl
require_cmd jq
require_cmd sha256sum

github_api() {
    local path=$1
    local headers=(-H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28")

    if [[ -n "${GH_TOKEN:-}" ]]; then
        headers+=(-H "Authorization: Bearer ${GH_TOKEN}")
    elif [[ -n "${GITHUB_TOKEN:-}" ]]; then
        headers+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
    fi

    curl -fsSL "${headers[@]}" "https://api.github.com${path}"
}

latest_caddy_version() {
    if [[ -n "${CADDY_VERSION_OVERRIDE:-}" ]]; then
        printf '%s\n' "$CADDY_VERSION_OVERRIDE"
        return
    fi

    github_api "/repos/caddyserver/caddy/releases/latest" | jq -er '.tag_name'
}

module_repo() {
    local module=$1
    local -a parts

    IFS=/ read -r -a parts <<<"$module"
    if [[ ${#parts[@]} -lt 3 || "${parts[0]}" != "github.com" ]]; then
        echo "error: plugin without a fixed version must be a GitHub module: $module" >&2
        exit 1
    fi

    printf '%s/%s\n' "${parts[1]}" "${parts[2]}"
}

latest_plugin_tag() {
    local repo=$1
    local tag

    if tag=$(github_api "/repos/${repo}/releases/latest" | jq -er '.tag_name' 2>/dev/null); then
        printf '%s\tgithub-release\n' "$tag"
        return
    fi

    tag=$(github_api "/repos/${repo}/tags?per_page=1" | jq -er '.[0].name')
    printf '%s\tgithub-tag\n' "$tag"
}

trim_line() {
    local line=$1
    line=${line%%#*}
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    printf '%s\n' "$line"
}

emit_output() {
    local name=$1
    local value=$2

    printf '%s=%s\n' "$name" "$value"
    if [[ -n "$github_output" ]]; then
        printf '%s=%s\n' "$name" "$value" >>"$github_output"
    fi
}

tmp_plugins=$(mktemp)
trap 'rm -f "$tmp_plugins"' EXIT

caddy_version=$(latest_caddy_version)
caddy_docker_version=${caddy_version#v}

while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    line=$(trim_line "$raw_line")
    [[ -z "$line" ]] && continue

    if [[ "$line" == *@* ]]; then
        module=${line%@*}
        version=${line##*@}
        source=fixed
    else
        module=$line
        repo=$(module_repo "$module")
        IFS=$'\t' read -r version source < <(latest_plugin_tag "$repo")
    fi

    jq -cn \
        --arg module "$module" \
        --arg version "$version" \
        --arg source "$source" \
        '{module: $module, version: $version, source: $source}' >>"$tmp_plugins"
done <"$plugins_file"

plugins_json=$(jq -s -c '.' "$tmp_plugins")
plugins_sha256=$(printf '%s' "$plugins_json" | sha256sum | awk '{print $1}')
plugins_sha_short=${plugins_sha256:0:12}

xcaddy_args=$(jq -r '.[] | "--with " + .module + "@" + .version' <<<"$plugins_json" | paste -sd' ' -)
image_version="${caddy_version}-plugins-${plugins_sha_short}"

emit_output caddy_version "$caddy_version"
emit_output caddy_docker_version "$caddy_docker_version"
emit_output plugins_json "$plugins_json"
emit_output plugins_sha256 "$plugins_sha256"
emit_output plugins_sha_short "$plugins_sha_short"
emit_output xcaddy_args "$xcaddy_args"
emit_output image_version "$image_version"
