#!/usr/bin/env bash
# GitHub Dependency graph の SBOM API から、指定したユーザー / org の
# 全リポジトリの依存ライブラリを集めて 1 つの CSV にまとめる。
#
# 使い方:
#   ./collect-deps.sh OWNER [OWNER ...]
#   例: ./collect-deps.sh mongolyy my-org
#
# 環境変数:
#   OUT_DIR=out            出力先 (既定: スクリプトと同じ場所の out/)
#   INCLUDE_FORKS=1        fork したリポジトリも含める (既定: 含めない)
#   INCLUDE_ARCHIVED=1     アーカイブ済みリポジトリも含める (既定: 含めない)
#
# 出力:
#   $OUT_DIR/dependencies.csv  owner,repo,ecosystem,package,version,purl,license
#   $OUT_DIR/errors.csv        取得できなかったリポジトリと理由
#
# 必要なもの: gh CLI (gh auth login 済み)。jq は不要 (gh 内蔵の --jq を使う)。

set -uo pipefail

if [ $# -eq 0 ]; then
  sed -n '2,19p' "$0"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT_DIR="${OUT_DIR:-$SCRIPT_DIR/out}"
mkdir -p "$OUT_DIR"
CSV="$OUT_DIR/dependencies.csv"
ERR="$OUT_DIR/errors.csv"

echo 'owner,repo,ecosystem,package,version,purl,license' > "$CSV"
echo 'owner,repo,reason' > "$ERR"

list_flags=(--limit 1000 --json name -q '.[].name')
[ "${INCLUDE_FORKS:-0}" = 1 ] || list_flags+=(--source)
[ "${INCLUDE_ARCHIVED:-0}" = 1 ] || list_flags+=(--no-archived)

total=0
failed=0

for owner in "$@"; do
  repos=$(gh repo list "$owner" "${list_flags[@]}" | tr -d '\r')
  for repo in $repos; do
    total=$((total + 1))
    printf '%s/%s ... ' "$owner" "$repo" >&2

    # リポジトリ自身 (DESCRIBES の対象) を除いた全パッケージを CSV 行にする
    # ($s や $roots は jq の変数なので、シェルで展開しないのが正しい)
    # shellcheck disable=SC2016
    jq_filter='
      .sbom as $s
      | [$s.relationships[]? | select(.relationshipType == "DESCRIBES") | .relatedSpdxElement] as $roots
      | $s.packages[]
      | select(.SPDXID as $id | ($roots | index($id)) | not)
      | ([(.externalRefs // [])[] | select(.referenceType == "purl") | .referenceLocator][0] // "") as $purl
      | [ "'"$owner"'", "'"$repo"'",
          (($purl | capture("^pkg:(?<t>[^/]+)/") | .t) // ""),
          .name, (.versionInfo // ""), $purl, (.licenseConcluded // "") ]
      | @csv'

    if rows=$(gh api "repos/$owner/$repo/dependency-graph/sbom" --jq "$jq_filter" 2>"$OUT_DIR/.last_err"); then
      rows=$(printf '%s' "$rows" | tr -d '\r')
      if [ -n "$rows" ]; then
        printf '%s\n' "$rows" >> "$CSV"
        echo "$(printf '%s\n' "$rows" | wc -l | tr -d ' ') packages" >&2
      else
        echo "0 packages" >&2
      fi
    else
      failed=$((failed + 1))
      reason=$(tr -d '\r' < "$OUT_DIR/.last_err" | tr '\n' ' ' | sed 's/"/""/g')
      case "$reason" in
        *"HTTP 404"*) reason="$reason(Dependency graph disabled or no supported manifest)" ;;
      esac
      echo "\"$owner\",\"$repo\",\"$reason\"" >> "$ERR"
      echo "FAILED" >&2
    fi
  done
done

rm -f "$OUT_DIR/.last_err"
echo >&2
echo "done: $total repos ($failed failed)" >&2
echo "  $CSV" >&2
echo "  $ERR" >&2
