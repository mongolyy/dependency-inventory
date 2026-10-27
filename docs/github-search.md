# GitHub の検索窓で使うクエリのテンプレート

`collect-deps.sh` を実行しなくても、GitHub のコード検索（https://github.com/search?type=code ）で「どのリポジトリが侵害されたパッケージを使っているか」の当たりをつけられます。サプライチェーン攻撃のニュースを見て、まずすぐ確認したいときに使います。

使い方: 下のクエリの `ORG`・`PKG`・`VER` を置き換えて、GitHub の検索窓に貼ります。

## まず知っておくこと

- **350 KiB を超えるファイルは検索の対象外**です。大きな `package-lock.json` や `yarn.lock` は引っかからないことがあるので、「見つからない＝使っていない」とは言えません。確実に調べるには `dependencies.csv` を使ってください。
- 検索の対象は**デフォルトブランチだけ**です。
- 複数の org をまとめて検索するときは `(org:ORG1 OR org:ORG2)` と書きます。自分のアカウントは `user:mongolyy` です。
- ログインしているアカウントで見られるリポジトリだけが結果に出ます。

## パッケージ名だけで探す（どのバージョンでも）

| エコシステム | クエリ |
|---|---|
| npm（package.json） | `org:ORG path:package.json "\"PKG\":"` |
| npm（lockfile 全般） | `org:ORG (path:package-lock.json OR path:yarn.lock OR path:pnpm-lock.yaml) "PKG"` |
| Python | `org:ORG (path:requirements OR path:pyproject.toml OR path:poetry.lock OR path:uv.lock OR path:Pipfile) "PKG"` |
| Go | `org:ORG (path:go.mod OR path:go.sum) "PKG "` |
| Ruby | `org:ORG path:Gemfile.lock "PKG ("` |
| Rust | `org:ORG path:Cargo.lock "name = \"PKG\""` |
| Maven / Gradle | `org:ORG (path:pom.xml OR path:build.gradle OR path:gradle.lockfile) "PKG"` |
| GitHub Actions | `org:ORG path:.github/workflows "uses: OWNER/ACTION@"` |

## バージョンまで指定して探す

lockfile のうち「パッケージ名とバージョンが同じ行に書かれる」形式なら、バージョンまで絞り込めます。

| ファイル | クエリ | 例 |
|---|---|---|
| package-lock.json / yarn.lock（npm レジストリの URL） | `org:ORG "/PKG/-/PKG-VER.tgz"` | `org:my-org "/axios/-/axios-1.6.0.tgz"` |
| スコープ付きパッケージ | `org:ORG "/@SCOPE/PKG/-/PKG-VER.tgz"` | `org:my-org "/@babel/core/-/core-7.24.0.tgz"` |
| pnpm-lock.yaml | `org:ORG path:pnpm-lock.yaml "PKG@VER"` | `org:my-org path:pnpm-lock.yaml "axios@1.6.0"` |
| requirements.txt | `org:ORG path:requirements "PKG==VER"` | `org:my-org path:requirements "requests==2.31.0"` |
| go.sum | `org:ORG path:go.sum "PKG vVER"` | `org:my-org path:go.sum "github.com/spf13/cobra v1.8.0"` |
| Gemfile.lock | `org:ORG path:Gemfile.lock "PKG (VER)"` | `org:my-org path:Gemfile.lock "rails (7.1.0)"` |
| Gradle | `org:ORG "GROUP:ARTIFACT:VER"` | `org:my-org "com.squareup.okhttp3:okhttp:4.12.0"` |
| GitHub Actions | `org:ORG path:.github/workflows "OWNER/ACTION@VER"` | `org:my-org path:.github/workflows "tj-actions/changed-files@v45"` |

`poetry.lock`・`uv.lock`・`Pipfile.lock`・`Cargo.lock`・`pom.xml` は、名前とバージョンが別の行に書かれるため、検索ではバージョンまで絞れません。パッケージ名で探してから、見つかったファイルの中を確認してください。

## 複数のバージョンをまとめて探す

侵害されたバージョンが複数あるときは `OR` でつなぎます。

```
org:ORG ("/PKG/-/PKG-1.2.3.tgz" OR "/PKG/-/PKG-1.2.4.tgz")
```

正規表現も使えます（`/.../` で囲む）。

```
org:ORG /\/PKG\/-\/PKG-1\.2\.[34]\.tgz/
```
