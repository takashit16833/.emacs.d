# .emacs.d

## Debian での動作確認

前提:

- Docker または Colima が利用できること
- GitHub CLI (`gh`) で `gh auth login` 済みであること

リポジトリ直下で次を実行する。

```sh
bash scripts/debian-test.sh
```

Debian trixie 上に GNU Emacs 31.1 をビルドした Docker イメージを作成し、
現在の `.emacs.d` を読み取り専用で渡して `emacs -nw --debug-init` を起動する。

初回は Emacs のビルドが必要だが、2回目以降は Docker のキャッシュを利用する。

コンテナ内のシェルで調査したい場合:

```sh
bash scripts/debian-test.sh shell
```

### Haskell LSP / format

Haskell用の検証プロジェクトを開く。

```sh
bash scripts/debian-test.sh emacs /workspace/haskell-lsp-test/app/Main.hs
```

検証用コンテナには GHC、Cabal、Haskell Language Server、Fourmolu と、
`haskell-ts-mode` 用の Tree-sitter grammar が入っている。

`Main.hs` は意図的に未整形にしてあるため、次を確認できる。

- `C-c l = =` で Fourmolu による手動整形が動く
- 未整形に戻して保存すると、同じ Fourmolu で自動整形される
- LSP の補完・診断・定義参照が動く

ツールのバージョンを確認する場合:

```sh
bash scripts/debian-test.sh shell -lc \
  'ghc --version; cabal --version; haskell-language-server-wrapper --version; fourmolu --version'
```

詳細は Workbench の `Notes/Emacs/Debian-動作確認.md` を参照。
