# .emacs.d

## Debian 系コンテナ

### 現場の既存コンテナへ導入する

現在の `.emacs.d` をコンテナ内に置いた状態で:

```sh
cd ~/.emacs.d
bash scripts/debian-setup.sh
```

依存パッケージ、GNU Emacs 31.1、GitHub 認証、UTF-8 / true color 環境を準備して Emacs を起動する。

セットアップ済みなら:

```sh
bash scripts/debian-emacs.sh
```

### まっさらな Debian で再現性を確認する

こちらは現場導入ではなくテスト用。

```sh
bash scripts/debian-test.sh
```

詳細は Workbench の `Notes/Emacs/Debian-動作確認.md` を参照。
