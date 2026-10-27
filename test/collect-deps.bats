#!/usr/bin/env bats
# collect-deps.sh のテスト。
# test/bin/gh (偽の gh) を PATH の先頭に置き、GitHub には通信せずに動かす。

bats_require_minimum_version 1.5.0

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../collect-deps.sh"
  PATH="$BATS_TEST_DIRNAME/bin:$PATH"
  export GH_FIXTURES="$BATS_TEST_DIRNAME/fixtures"
  export GH_CALLS="$BATS_TEST_TMPDIR/gh-calls.log"
  export OUT_DIR="$BATS_TEST_TMPDIR/out"
  unset INCLUDE_FORKS INCLUDE_ARCHIVED
}

@test "引数なしなら使い方を表示して exit 1" {
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"使い方"* ]]
}

@test "dependencies.csv にヘッダーと各パッケージの行が出る" {
  run "$SCRIPT" mongolyy
  [ "$status" -eq 0 ]

  run cat "$OUT_DIR/dependencies.csv"
  [ "${lines[0]}" = 'owner,repo,ecosystem,package,version,purl,license' ]
  [ "${lines[1]}" = '"mongolyy","repo-a","npm","axios","1.6.0","pkg:npm/axios@1.6.0","MIT"' ]
  [ "${lines[2]}" = '"mongolyy","repo-a","pypi","requests","2.31.0","pkg:pypi/requests@2.31.0",""' ]
  [ "${lines[3]}" = '"mongolyy","repo-a","","mystery","","",""' ]
  [ "${#lines[@]}" -eq 4 ]
}

@test "リポジトリ自身 (DESCRIBES の対象) は CSV に含めない" {
  "$SCRIPT" mongolyy 2>/dev/null
  run ! grep -q 'com.github.mongolyy' "$OUT_DIR/dependencies.csv"
}

@test "依存が 0 件のリポジトリは 0 packages と表示し、行を出さない" {
  run "$SCRIPT" mongolyy
  [[ "$output" == *"mongolyy/repo-empty ... 0 packages"* ]]
  run ! grep -q 'repo-empty' "$OUT_DIR/dependencies.csv"
}

@test "HTTP 404 のリポジトリは errors.csv に理由付きで記録する" {
  run "$SCRIPT" mongolyy
  [ "$status" -eq 0 ]
  [[ "$output" == *"mongolyy/repo-missing ... FAILED"* ]]
  [[ "$output" == *"done: 3 repos (1 failed)"* ]]

  run cat "$OUT_DIR/errors.csv"
  [ "${lines[0]}" = 'owner,repo,reason' ]
  [[ "${lines[1]}" == '"mongolyy","repo-missing","'*'HTTP 404'*'Dependency graph disabled'*'"' ]]
  [ "${#lines[@]}" -eq 2 ]
}

@test "複数の owner をまとめて 1 つの CSV にする" {
  run "$SCRIPT" mongolyy my-org
  [[ "$output" == *"done: 4 repos (1 failed)"* ]]
  grep -qF '"my-org","tool","golang","github.com/spf13/cobra","1.8.0"' "$OUT_DIR/dependencies.csv"
}

@test "既定では fork とアーカイブ済みを除く" {
  "$SCRIPT" mongolyy 2>/dev/null
  run grep '^repo list mongolyy' "$GH_CALLS"
  [[ "$output" == *"--source"* ]]
  [[ "$output" == *"--no-archived"* ]]
}

@test "INCLUDE_FORKS=1 と INCLUDE_ARCHIVED=1 で除外をやめる" {
  INCLUDE_FORKS=1 INCLUDE_ARCHIVED=1 "$SCRIPT" mongolyy 2>/dev/null
  run grep '^repo list mongolyy' "$GH_CALLS"
  [[ "$output" != *"--source"* ]]
  [[ "$output" != *"--no-archived"* ]]
}

@test "2 回目の実行で前回の結果に追記せず作り直す" {
  "$SCRIPT" mongolyy 2>/dev/null
  "$SCRIPT" mongolyy 2>/dev/null
  [ "$(wc -l < "$OUT_DIR/dependencies.csv")" -eq 4 ]
  [ "$(wc -l < "$OUT_DIR/errors.csv")" -eq 2 ]
}
