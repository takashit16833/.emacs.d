# Emacs 設定整理計画

このファイルは `refactor/config` ブランチで行う設定整理の計画、判断、検証結果、進捗を記録する。
作業が中断しても、別の担当者がこのファイルと Git の履歴から再開できる状態を保つ。

## 目的

- `config/` は設定・有効化・キー割り当て、`elisp/` は独自処理本体という現在の区分を維持する。
- ファイル名と責務を合わせ、巨大化したファイルから独立性の高い処理を分離する。
- 二重定義、未定義参照、重複設定を解消する。
- セクション見出し、空行、コメントの書き方を Emacs Lisp の慣例に沿って揃える。
- 動作、遅延読み込み、macOS / Debian、端末版 Emacs という既存要件を維持する。

## 作業原則

1. 挙動変更を目的としない。整理と機能変更を同じコミットに混ぜない。
2. 未使用に見えるコードも、参照と意図を確認できないまま削除しない。
3. 分割時は既存の公開関数名を維持し、呼び出し側への影響を最小限にする。
4. 各段階で静的確認と ERT を行い、結果をこのファイルへ記録する。
5. 一段階を完了するたびに、このファイルを更新してコミット・pushする。
6. Emacs 31.1 で obsolete の `if-let` / `when-let` は使用しない。

## 初期状態

- ブランチ: `refactor/config`
- 調査開始時の HEAD: `7ddcd27`
- `config/`: 13ファイル
- `elisp/`: 22ファイル（`.gitkeep` を除く）
- `test/`: 20個の単体テストファイル、1個の結合テストファイル
- 最大ファイル:
  - `elisp/my-haskell-indent.el`: 520行
  - `config/org.el`: 367行
  - `config/development.el`: 282行
  - `elisp/my-development.el`: 280行
  - `elisp/my-editing.el`: 271行
  - `elisp/my-ui.el`: 232行
  - `elisp/my-project.el`: 231行

### 確認済みの問題

- `my/delete-to-line-beginning` が `elisp/my-editing.el` で二重定義されている。
- `config/editing.el` が未定義の `my/select-to-line-beginning` を割り当てている。
- `/root/.ghcup/bin` の `tramp-remote-path` 追加が `config/terminal.el` と
  `config/development.el` に重複している。
- `elisp/my-ui.el` のファイル説明が内容と一致していない。
- `elisp/my-development.el` に Flymake 表示、GHCi補完、jq、Python用Eglot処理が混在している。
- `elisp/my-project.el` にプロジェクトコマンド実行とDB接続処理が同居している。
- `config/org.el` に Org 基本設定、表示、Agenda、Pomodoro が同居している。
- セクション見出しが `;;; Name -----`、罫線コメント、見出しなしで混在している。

### すぐには削除しないもの

`elisp/my-haskell-indent.el` は現在の起動設定から参照されず、代わりに
`my-haskell-simple-indent.el` が使われている。ただし前者には独立した多数の ERT があり、
実験実装または予備実装として残している可能性がある。この整理では、未使用という理由だけで削除しない。

### 検証環境の制約

作業用コンテナには現在 `emacs` コマンドがない。そのため、ここでは参照検索、構文上の
括弧対応、差分確認などの静的検証を実施する。ERT と Emacs 31.1 での起動確認は、
実行可能な環境が得られた時点で必ず行い、未実施のままなら最終状態に明記する。

## 計画と進捗

| 段階 | 内容 | 状態 |
|---|---|---|
| 0 | 初期調査と本管理ファイルの追加 | 完了 |
| 1 | 二重定義・未定義参照・重複設定の解消 | 未着手 |
| 2 | `my-ui.el` から Tab-line 処理を `my-tab-line.el` へ分離 | 未着手 |
| 3 | `my-development.el` を GHCi、jq、Python、Flymake の責務へ分離 | 未着手 |
| 4 | `my-project.el` からDB接続処理を `my-project-database.el` へ分離 | 未着手 |
| 5 | `config/org.el` を基本・表示・Agenda・Pomodoroへ整理 | 未着手 |
| 6 | `config/development.el` の言語別設定と共通設定を整理 | 未着手 |
| 7 | セクション見出し・コメント・空行を統一 | 未着手 |
| 8 | 全参照、全テスト、起動、差分の最終確認 | 未着手 |

## 段階ごとの完了条件

### 1. 明確な不整合の解消

- 二重定義を1つに統合する。
- `my/select-to-line-beginning` を既存の行末選択と対になる形で実装し、ERTを追加する。
- GHCup の TRAMP パス設定を端末・リモート環境を扱う `config/terminal.el` に一本化する。

### 2. Tab-line の分離

- Tab-line固有の変数、face、Git状態キャッシュ、表示関数を `my-tab-line.el` へ移す。
- ファイルアイコンの共通処理は `my-ui.el` に残す。
- `config/navigation.el` と `config/git.el` は新しい feature を明示的に読み込む。
- Tab-lineの既存テストは `my-tab-line` を直接対象にする。

### 3. 開発用独自処理の分離

- GHCi補完を `my-haskell-ghci.el` へ移す。
- jq Playgroundを `my-jq.el` へ移す。
- Python用Language Server解決を `my-python.el` へ移す。
- Flymake診断文字列処理は実際の参照を確認し、適切な既存モジュールへ移すか、未使用なら削除候補として判断を記録する。
- 対応するテストのファイル名と `require` を責務に合わせる。

### 4. プロジェクトDB処理の分離

- プロジェクトローカル値の読み取りという共通処理は `my-project.el` に残す。
- DB接続変数、検証、起動処理を `my-project-database.el` へ移す。
- テストをコマンド実行とDB接続に分ける。

### 5. Org設定の整理

- `config/org.el`: 保存先、Org基本設定、キャプチャ、Orgバッファ固有処理。
- `config/org-appearance.el`: org-modern、Orgブロック・表・優先度等の表示。
- `config/org-agenda.el`: Agenda、org-super-agenda、2行表示。
- `config/org-pomodoro.el`: Pomodoroと通知音。
- OS固有の音声再生コマンドは利用可能性を考慮し、macOS固定のまま隠さない。
- `init.el` で読み込み順を明示する。

### 6. 開発設定の整理

- Eglot、Flymake、整形など複数言語に共通する設定と、言語固有設定の境界を明確にする。
- 分割する場合も、読み込み順や `with-eval-after-load` による遅延読み込みを維持する。
- 小さすぎるファイルを増やすだけになる場合は分割せず、セクション整理に留める。

### 7. 書式統一

- 大区分は `;;; Name`、説明は `;; ...` を使用する。
- 装飾目的だけの長い罫線は除去する。
- コメントは処理の逐語説明より、設定理由・制約・削除条件を優先する。
- 機械的な全整形で無関係な巨大差分を作らず、対象ファイル単位で確認する。

## 検証方法

実行可能な環境では、リポジトリのルートから次を実行する。

```sh
test/run-all-tests.sh
emacs -Q --batch -L elisp --eval \
  "(progn (mapc #'byte-compile-file (directory-files \"elisp\" t \"[.]el$\")))"
emacs --batch --init-directory "$PWD" --eval '(kill-emacs 0)'
```

追加で、各段階で次を確認する。

```sh
git diff --check
rg "my/select-to-line-beginning|tramp-remote-path|my/tab-line|my/project-database" \
  config elisp test
```

byte compileで生成される `.elc` はコミットしない。

## 進捗記録

### 2026-10-21: 初期調査

- `refactor/config` の HEAD `7ddcd27` から開始した。
- ファイル行数、`require` / `provide`、主要な参照関係を静的に確認した。
- 上記の確認済み問題と責務分離候補を確定した。
- 作業用コンテナに Emacs がないことを確認した。

## 再開手順

1. `git status --short --branch` で未コミット変更を確認する。
2. このファイルの「計画と進捗」で最初の未完了段階を確認する。
3. 「進捗記録」と直近の `git log --oneline` を読み、完了済み作業を再実行しない。
4. 対象段階の参照を `rg` で再確認してから変更する。
5. 検証結果と判断をこのファイルへ追記し、コードと同じ区切りでコミット・pushする。
