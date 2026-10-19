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

### 依存関係

macOSのWezTermでMermaidを透過表示するために、別途必要なコマンドは **`mmdc` と `chafa`**。加えて、`mmdc` のインストールにはNode.js/npmが必要。

```sh
# Mermaid CLIのインストールに必要なNode.jsと、透過Sixel変換用のChafa
brew install node chafa

# MermaidをPNGへ変換するCLI
npm install --global @mermaid-js/mermaid-cli@11

# インストール確認
mmdc --version
chafa --version
```

- **`mmdc`**：MermaidのソースコードからPNGを生成する（Mermaid CLI 11系）。
- **`chafa`**：WezTermで透過PNGをSixelに変換する。Kitty Graphics Protocolで表示するKittyでは不要。
- **Emacsパッケージ**：`ob-mermaid` と `kitty-graphics.el` は設定から自動導入する。初回はネットワーク接続が必要。
- **任意の代替エンコーダー**：Chafaがない場合は `img2sixel`（`brew install libsixel`）またはImageMagickへフォールバックする。ただし、透過背景の表示にはChafaを使用する。

端末の画像描画はKittyとWezTermの `emacs -nw` で自動有効化する。KittyではKitty Graphics Protocol、WezTermではSixelを選択する。バックエンドは `M-x kitty-graphics-doctor` で確認できる。

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

### WezTermの透過PNG表示

WezTermではSixelへの変換にChafaを優先し、透過PNGを背景画像の上に重ねて表示する（`brew install chafa`）。
Chafaの出力から画像用Sixel DCSだけを取り出すことで、端末のカーソル位置・行送りをEmacs本体に任せる。
エンコーダーごとにキャッシュファイル名を分け、以前の`img2sixel`出力が再利用されないようにする。
Chafaは端末照会を無効にした状態で仮想セルを10×20pxとして計算するため、`kitty-graphics.el`が測定した端末セルの実ピクセル寸法（例: 16×32px）から出力セル数を換算する。これにより、Emacsが確保する表示領域とChafaのSixel画像の大きさを合わせる。取得できなければkitty-graphics標準の8×16pxを使う。
セルのピクセル寸法が変わった場合はSixelキャッシュも別名になる。
表示は**Emacs再起動後**に確認する。Kittyと非WezTermでは従来のエンコーダーを維持する。

### WezTerm + Sixelの表示制約

WezTermでSixelを使うと、スクロール中の画像表示は動く一方、`kitty-graphics.el` が古い画像領域を空白で消去すると、周辺の本文まで消える現象が確認された。そのため **WezTerm + Sixelのときだけ `kitty-graphics--sixel-delete` の実行を抑止**する。Kittyなど他の環境の削除処理は変更しない。

- **利点:** スクロール時にOrg本文が欠ける現象を回避する
- **制約:** ページ送り、バッファ切り替え、画面分割、プレビュー解除などで画像の残像が残る場合がある。表示が乱れたら `M-x redraw-display` を試す
- **マウス:** `xterm-mouse-mode` は従来どおり有効のまま。マウスホバー時に画像が消える現象は別問題のため、画像の上へのホバーを避ける
- **切り替え:** `M-: (list kitty-graphics-mode kitty-graphics--active-backend)` の結果が `(t sixel)` ならSixelが有効
- **初回適用:** 以前 `M-:` から手動で登録した `advice-add ... :override #'ignore` を残さないため、Git更新後にEmacsを再起動する

この回避策は端末への画像配置を根本修正するものではない。文字の消失を避けることを優先した暫定対応であり、実機での長時間利用・画面分割・再起動後の安定性は継続確認する。

単体ERTではプレビュー用画像生成指示・キャッシュと、WezTerm + Sixelに限定した画像消去の抑止を検証する。実際の画像描画・スクロールは実機での確認が必要。

## テスト

リポジトリ直下で単体ERTと結合ERTをまとめて実行する。

```sh
sh test/run-all-tests.sh
```

