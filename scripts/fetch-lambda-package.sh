#!/usr/bin/env bash
# Terraform "external" data source program: downloads a single Lambda package asset from a
# tagged GitHub Release of the backend repo, caching it locally by tag, and reports back its
# path and base64-encoded SHA-256 digest (matching Terraform's filebase64sha256() format) so
# lambda_*.tf can reference it as source_code_hash without re-downloading on every plan/apply.
#
# Protocol: reads a JSON object on stdin with keys repo, tag, asset, cache_dir; writes a JSON
# object on stdout with keys path, sha256_base64. See:
# https://developer.hashicorp.com/terraform/language/data-sources/external
set -euo pipefail

input="$(cat)"
repo="$(jq -r '.repo' <<<"$input")"
tag="$(jq -r '.tag' <<<"$input")"
asset="$(jq -r '.asset' <<<"$input")"
cache_dir="$(jq -r '.cache_dir' <<<"$input")"

if [[ -z "$repo" || -z "$tag" || "$tag" == "null" || -z "$asset" || -z "$cache_dir" ]]; then
  echo "fetch-lambda-package.sh: repo, tag, asset, and cache_dir are all required (got repo='$repo' tag='$tag' asset='$asset' cache_dir='$cache_dir')" >&2
  exit 1
fi

dest_dir="$cache_dir/$tag"
dest_path="$dest_dir/$asset"
mkdir -p "$dest_dir"

if [[ ! -f "$dest_path" ]]; then
  url="https://github.com/$repo/releases/download/$tag/$asset"
  if ! curl -sSfL -o "$dest_path.tmp" "$url"; then
    echo "fetch-lambda-package.sh: failed to download $url" >&2
    rm -f "$dest_path.tmp"
    exit 1
  fi
  mv "$dest_path.tmp" "$dest_path"
fi

sha256_base64="$(openssl dgst -sha256 -binary "$dest_path" | openssl base64 -A)"

jq -n --arg path "$dest_path" --arg sha256_base64 "$sha256_base64" \
  '{path: $path, sha256_base64: $sha256_base64}'
