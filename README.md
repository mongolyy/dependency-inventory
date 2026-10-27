# dependency-inventory

GitHub の Dependency graph（SBOM API）を使って、自分や自分の org の全リポジトリが使っているライブラリとバージョンを 1 つの CSV にまとめるツールです。

サプライチェーン攻撃が起きたときに「侵害されたパッケージ `xxx@1.2.3` を使っているリポジトリはどれか」をすぐ答えられるようにすることが目的です。

## 必要なもの

- [GitHub CLI](https://cli.github.com/)（`gh auth login` 済み。private リポジトリを読むには `repo` スコープ、org を読むには `read:org` が必要です）
- bash（Windows では Git Bash で動きます）

jq は不要です（gh に内蔵の `--jq` を使います）。

## 使い方

```bash
./collect-deps.sh mongolyy            # 自分のアカウント
./collect-deps.sh mongolyy my-org     # 複数のアカウント / org
```

| 環境変数 | 意味 |
|---|---|
| `OUT_DIR=path` | 出力先（既定: `out/`） |
| `INCLUDE_FORKS=1` | fork したリポジトリも含める |
| `INCLUDE_ARCHIVED=1` | アーカイブ済みリポジトリも含める |

## 出力

- `out/dependencies.csv`: `owner,repo,ecosystem,package,version,purl,license`
- `out/errors.csv`: 取得できなかったリポジトリと理由

### 検索の例

```bash
# 特定パッケージを使っているリポジトリ
grep '"axios"' out/dependencies.csv
```

CSV を作る前にすぐ当たりをつけたいときは、GitHub のコード検索も使えます。検索窓に貼るクエリのテンプレートは [docs/github-search.md](docs/github-search.md) にあります（大きな lockfile は検索の対象外なので、確実に調べるには CSV を使ってください）。

## テスト

[bats-core](https://github.com/bats-core/bats-core) と shellcheck を使います。`test/bin/gh` は本物の GitHub に通信しない偽の gh で、`test/fixtures/` のファイルを返します（jq が必要です）。push と pull request のたびに GitHub Actions でも実行されます。

```bash
shellcheck collect-deps.sh test/bin/gh
bats test/
```

Windows で手元に bats や jq が無い場合は、Docker で CI と同じ環境を使えます。

```bash
docker run --rm -v "$PWD:/work" -w /work ubuntu:24.04 bash -c 'apt-get update -qq && apt-get install -y -qq bats jq shellcheck >/dev/null && shellcheck collect-deps.sh test/bin/gh && bats test/'
```

## 制約

- **HTTP 404**: そのリポジトリで Dependency graph が無効か、対応する依存ファイルがありません。private リポジトリは Settings → Code security で Dependency graph を有効にしてください（org 単位で一括有効化もできます）。
- **言語のバージョン**（Node.js、Go、Python 本体など）は Dependency graph の対象外のため取れません。
- **直接の依存と推移的な依存の区別**は SBOM API が返さないため、区別していません。
- lockfile が無いリポジトリでは、バージョンが `^1.2.3` のような範囲指定のまま出ることがあります。
