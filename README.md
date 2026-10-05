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
bash scripts/debian-test.sh --shell
```

詳細は Workbench の `Notes/Emacs/Debian-動作確認.md` を参照。
