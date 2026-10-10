# セットアップ

## macOS

HomebrewとXcode Command Line Toolsを用意する。Cコンパイラがなければ `xcode-select --install` を実行する。

```sh
brew install emacs git ripgrep cmake libvterm
emacs --version
```

`GNU Emacs 31.1` であることを確認する。

## Debian（Emacsを直接起動する場合）

GNU Emacs 31.1（Tree-sitter対応ビルド）を用意し、次のコマンドを準備する。

```sh
sudo apt update
sudo apt install -y git ripgrep build-essential cmake libvterm-dev
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

この移行ブランチでは、EmacsからLanguage Serverを起動する設定はまだ追加していない。Eglotの導入時に設定する。

| 言語 | Language Server | フォーマッタなど |
| --- | --- | --- |
| Lua | `lua-language-server` | `stylua` |
| Haskell | `haskell-language-server-wrapper` | `fourmolu`、Cabalには `cabal-gild` |
| PHP | `intelephense` | `phpcbf` |
| Python | `pyright-langserver` | `ruff` |
| TypeScript / TSX | `typescript-language-server` とプロジェクト内の `typescript` | `prettier` |

Node.js/npmを使用するLanguage Serverは、例えば次のようにインストールできる。

```sh
npm install --global intelephense typescript-language-server pyright
```

TypeScript本体はプロジェクトで管理する。

```sh
npm install --save-dev typescript
```

TRAMPの場合、Language Server・フォーマッタは**接続先**で実行する。Tree-sitter文法のインストール先とは異なるので注意する。

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

## テスト

リポジトリ直下で単体ERTと結合ERTを実行する。

```sh
sh test/run-all-tests.sh
```

結合テストがある場合は、同じスクリプトから実行する。
