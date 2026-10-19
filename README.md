# セットアップ

## macOS

HomebrewとXcode Command Line Toolsを用意する。Cコンパイラがなければ `xcode-select --install` を実行する。

```sh
brew install emacs git ripgrep jq cmake libvterm coreutil
emacs --version
```

`GNU Emacs 31.1` であることを確認する。

## Debian（Emacsを直接起動する場合）

GNU Emacs 31.1（Tree-sitter対応ビルド）を用意し、次のコマンドを準備する。

```sh
sudo apt update
sudo apt install -y git ripgrep jq build-essential cmake libvterm-dev
emacs --version
```

OSのパッケージがEmacs 31.1とは限らないため、バージョンを必ず確認する。Debian trixieでEmacs 31.1をビルドする際の依存パッケージは `docker/debian/Dockerfile` に記載している。

## 設定の配置と起動

既存の `~/.emacs.d` がある場合は、先に退避する。

```sh
git clone https://github.com/takashit16833/.emacs.d.git ~/.emacs.d
emacs -nw
```

初回起動時は、設定内の `use-package` が必要なEmacsパッケージを取得するため、ネットワーク接続が必要。

## 既知の問題・調査記録

- [macOS / Emacs 31.1 TTYでOrgファイル指定起動時に発生したSegmentation fault](docs/tty-org-startup-segfault.md) — 再現条件、切り分け結果、タブバー関連の回避策と未解明の点。

## Tree-sitter文法

**文法はEmacs本体を実行しているOSにインストールする。** macOSのEmacsからTRAMPでDocker内のファイルを開く場合も、文法はmacOS側に必要。Docker内で `emacs -nw` を実行する場合はDocker側に必要。

EmacsでTree-sitterを利用できるか確認する。

```elisp
(treesit-available-p)
```

`M-:` で評価して `t` なら利用可能。

### Lua / Python / TypeScript / TSX

まず利用する言語の設定を `M-:` で読み込む。

| ファイル | 評価する式 |
| --- | --- |
| `.lua` | `(require 'lua-ts-mode)` |
| `.py` | `(require 'python)` |
| `.ts` / `.tsx` | `(require 'typescript-ts-mode)` |

続いて、Emacsで次を実行する。

```text
M-x treesit-install-language-grammar
```

`Language:` には対応する `lua`、`python`、`typescript`、`tsx` を入力する。インストール先はEnterで既定の `~/.emacs.d/tree-sitter/` を使う。

ビルドにはGit、Cコンパイラ、および必要に応じてC++コンパイラが必要。

### PHP

PHPはHTML・CSS・JavaScript・PHPDocの文法も使用するため、専用のインストールコマンドを使う。

```text
M-: (require 'php-ts-mode) RET
M-x php-ts-mode-install-parsers
```

これにより `php`、`phpdoc`、`html`、`javascript`、`jsdoc`、`css` をインストールする。

### Haskell

`haskell-ts-mode` では、標準のHaskell文法とは別の `dschrempf/tree-sitter-haskell` を使用する。現在のDocker検証環境と同じリビジョンを使う。

まずTree-sitter CLIを用意する。macOSでは次を実行する。

```sh
brew install tree-sitter-cli
```

Debianでは `tree-sitter-cli` パッケージを使用できる環境ならそれをインストールする。

```sh
sudo apt install -y tree-sitter-cli
```

文法を生成して `~/.emacs.d/tree-sitter/` に配置する（macOS / Debian共通）。

```sh
tmp=$(mktemp -d)
git clone https://github.com/dschrempf/tree-sitter-haskell.git "$tmp/tree-sitter-haskell"

(
  cd "$tmp/tree-sitter-haskell" || exit 1
  git checkout f3fd0ad1e47aa0ff590479afb1f3e8275e4381cb
  tree-sitter generate src/grammar.json --abi=14
  cc -std=c11 -fPIC -Isrc -c src/parser.c -o parser.o
  cc -std=c11 -fPIC -Isrc -c src/scanner.c -o scanner.o
  mkdir -p "$HOME/.emacs.d/tree-sitter"

  case "$(uname -s)" in
    Darwin)
      cc -dynamiclib parser.o scanner.o \
        -o "$HOME/.emacs.d/tree-sitter/libtree-sitter-haskell.dylib" ;;
    Linux)
      cc -shared parser.o scanner.o \
        -o "$HOME/.emacs.d/tree-sitter/libtree-sitter-haskell.so" ;;
  esac
)
rm -rf "$tmp"
```

### インストール確認

Emacsの `M-:` で、利用する文法を確認する。

```elisp
(treesit-language-available-p 'typescript)
(treesit-language-available-p 'tsx)
(treesit-language-available-p 'php)
(treesit-language-available-p 'haskell)
(treesit-language-available-p 'lua)
(treesit-language-available-p 'python)
```

必要な文法が `t` ならOK。すでに開いているファイルは `M-x normal-mode` でメジャーモードを判定し直す。文法がなく `fundamental-mode` になる場合は、まずこの結果を確認する。

## Language Server・フォーマッタ

Emacsパッケージとは別に、Language Serverやフォーマッタの実行ファイルが必要。実際に使用する言語のものだけ用意する。

Emacs 31.1標準のEglotを使用する。Lua・Haskell・PHP・Python・TypeScript・TSXのファイルを開くと、自動的にLanguage Serverへの接続を試みる。

| 言語 | Language Server | フォーマッタなど |
| --- | --- | --- |
| Lua | `lua-language-server` | `stylua` |
| Haskell | `haskell-language-server-wrapper` | `fourmolu`、Cabalには `cabal-gild` |
| PHP | `intelephense` | `phpcbf` |
| Python | `basedpyright-langserver` | `ruff` |
| TypeScript / TSX | `typescript-language-server` とプロジェクト内の `typescript` | `prettier` |
| JSON | なし | `jq` |

Node.js/npmを使用するLanguage Serverは、例えば次のようにインストールできる。

```sh
npm install --global intelephense typescript-language-server basedpyright
```

Pythonでは、プロジェクト内の `.venv/bin/basedpyright-langserver` を優先し、見つからなければ `PATH` 上の `basedpyright-langserver` を使用する。既存の `.venv` にインストールする場合は次のコマンドを実行する。

```sh
.venv/bin/python -m pip install basedpyright
```

TypeScript本体はプロジェクトで管理する。

```sh
npm install --save-dev typescript
```

TRAMPの場合、Language Server・フォーマッタは**接続先**で実行する。Tree-sitter文法のインストール先とは異なるので注意する。

### Eglotの動作確認

まずローカルのプロジェクト内で対象言語のファイルを開き、Emacsの `M-:` で次を評価する。

```elisp
(eglot-managed-p)
```

`t` ならEglotの管理下にある。接続できない場合は `M-x eglot` を手動実行し、エラーを確認する。`M-x eglot-events-buffer` で通信内容も確認できる。

| 操作 | キーまたはコマンド |
| --- | --- |
| 定義へ移動 | `M-.` |
| 参照を検索 | `M-?` |
| 補完 | Corfuで候補を選択、または `M-x completion-at-point` |
| 現在のファイルの診断一覧 | `M-x flymake-show-buffer-diagnostics` |
| プロジェクトの診断全文一覧 | `S-s-m`（`my/flymake-problems`） |
| カーソル位置の説明 | `M-x eldoc` |
| シンボル名を変更 | `M-x eglot-rename` |
| 型・引数名ヒントを確定 | `C-c l i`（`my/eglot-apply-inlay-hint`、サーバーが編集情報を返す場合） |

変数名の型注釈に加え、`json.dumps(result)` の `result` のような単純な引数名にカーソルを置くと、`obj=` などの引数名ヒントも反映できる。関数の戻り値や、辞書・関数呼び出しなどシンボル以外の引数式は対象外。

Corfuの候補一覧には、Eglot（LSP）の候補とdabbrev（バッファ内の単語）を統合して表示する。Haskellでは修飾名の補完（例: `T.un` → `unpack`）と、未importの関数を補完した際の自動importにも対応する。HLSの補完候補数の上限は200件に設定している。EglotのSemantic Tokensによる色分けは全言語で無効にし、文字色は各言語のメジャーモード（HaskellではTree-sitter）に任せている。

`S-s-m` はプロジェクト内の診断メッセージを複数行のまま全文表示する。`RET` で診断位置へ移動、`n` / `p` で次・前、`g` で更新、`q` で閉じる。対象はFlymakeが把握している診断であり、プロジェクト内の全ファイルを自動検査するコマンドではない。

## Debian検証用Docker

Docker（またはColima）とGitHub CLIを用意し、ホストで `gh auth login` を済ませる。

リポジトリ直下で実行する。

```sh
# コンテナ内でEmacsを起動する（未作成ならビルドする）
bash scripts/debian-test.sh

# シェルを開く
bash scripts/debian-test.sh shell

# 起動・停止・再ビルド
bash scripts/debian-test.sh start
bash scripts/debian-test.sh stop
bash scripts/debian-test.sh rebuild
```

検証用Dockerイメージには各言語のTree-sitter文法とLanguage Serverを用意している。ホスト上のEmacsからDockerへTRAMP接続する場合は、上記「Tree-sitter文法」の手順をホスト側でも実行する。

## OrgでのMermaidプレビュー（端末版）

Org Babelの画像生成には [ob-mermaid](https://github.com/arnm/ob-mermaid) を使用する。
端末への画像表示には [kitty-graphics.el](https://github.com/cashmeredev/kitty-graphics.el) を使用し、画像の配置処理は独自実装しない。

- 画像生成には `mmdc`（Mermaid CLI 11系）を使用する。バージョンを `mmdc --version` で確認する
- `ob-mermaid` はOrgを開いた際に自動導入・読み込みする。初回はネットワーク接続が必要
- 端末の画像描画はKitty上の `emacs -nw` でのみ自動有効化する。WezTermは画像スクロール中の異常終了が未解決のため、自動有効化しない

Mermaidのソースブロックを作り、ブロックの中で `M-x my/org-mermaid-preview` を実行する。

```org
#+begin_src mermaid
flowchart LR
    A[設計] --> B[実装] --> C[評価]
#+end_src
```

- `:file` を書かなくてもよい。プレビュー用PNGを `~/images/mermaid/` に生成し、標準の `#+RESULTS:` 画像リンクを挿入する
- 同じソースと描画設定なら生成済みPNGを再利用し、`mmdc` を再実行しない
- ソースを変更すると別のPNG名になるため、端末内の古い画像キャッシュと衝突しにくい
- 出力画像はGit管理外のホームディレクトリに保持する。Org文書を別のPCに移した場合、再度プレビューコマンドを実行する
- Orgファイルを開き直して画像が非表示なら `C-c C-x C-v` で標準の画像表示を切り替える
- コードをたたむ場合はOrg標準の折りたたみ機能を使う

通常のOrg Babel実行（`C-c C-c`）で画像生成することもできる。その場合は`ob-mermaid`の仕様どおり、`#+begin_src mermaid :file example.png` のように `:file` を指定する。プレビュー用コマンドとは異なり、出力先はブロックに記載したパスとなる。

現段階での自動テストは画像生成指示とファイル管理まで。**実際のKitty上でのスクロール・画面分割・再起動時の安定性は、実機で検証する必要がある。**

## テスト

リポジトリ直下で単体ERTと結合ERTをまとめて実行する。

```sh
sh test/run-all-tests.sh
```

