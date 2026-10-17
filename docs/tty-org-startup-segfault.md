# Emacs 31.1 / macOS TTY: Orgファイル指定起動時のSegmentation fault

- 調査日: 2026-10-17
- 検証環境: macOS、WezTerm、GNU Emacs 31.1、`emacs -nw`
- 状態: **回避策あり。Emacs本体の根本原因は未特定。**
- 関連設定: [`config/navigation.el`](../config/navigation.el) の `tab-bar` 設定

## 現象

通常の設定でOrgファイルをコマンドライン引数に指定して起動すると、Segmentation faultが発生した。
最小のOrgファイルでも発生し、Org文書の内容には依存しなかった。

```sh
printf '* Test\nHello World\n' > /tmp/org-crash-test.org
emacs -nw /tmp/org-crash-test.org
```

ネイティブのバックトレースには `tty_write_glyphs_1`、`update_frame`、
`redisplay_internal` などが現れた。Emacs Lispの通常のエラーではなく、
TTYでの描画処理中に発生するクラッシュである。

対照的に、`emacs -Q -nw /tmp/org-crash-test.org` は正常であり、
通常起動後に `C-x C-f` で同じファイルを開く操作も正常だった。
起動時の `find-file` はクラッシュするが、`window-setup-hook` や
アイドルタイマーから開くと正常になることも確認した。

## 切り分けから分かったこと

| 条件 | 観測結果 |
| --- | --- |
| `emacs -Q -nw` でOrgファイルを指定 | 正常 |
| 元の個人設定でOrgファイルを指定 | クラッシュ |
| `appearance.el` + `navigation.el` のみ | 正常 |
| 7設定ファイルの構成 | 一度は正常だったが、その後同一コマンドで3回連続クラッシュ |
| 起動時の `default-frame-alist` を `nil` にする | 正常 |
| `default-frame-alist` に `((tab-bar-lines . 1))` を指定 | 正常 |
| `default-frame-alist` を空にし、現在のフレームへ `tab-bar-lines=0` を直接指定 | 正常 |
| 元の `init.el` を読み込み、`default-frame-alist` から `tab-bar-lines` だけ除外 | 正常（本文表示・`C-l`） |
| 上記の回避状態で `M-x tab-new` | 2個目のタブでタブバーが表示された |

**重要:** 7ファイル構成が途中からクラッシュするようになったため、
設定ファイルやライブラリを1個追加しただけで原因だと断定してはいけない。
`development.el`、`comint`、`ansi-color`、さらには空の `--eval '(progn)'`
を追加してもクラッシュしたが、その後、追加なしの基準構成も3回連続でクラッシュした。
これらのライブラリが原因と示されたわけではない。

自動保存の `auto-save-file-name-transforms` の第3要素を
`t` から `sha256` に変更する実験も行った。
部分構成で正常になる場合はあったが、全設定でのクラッシュは解消しなかった。
最終的に **元の自動保存設定（`t`）のままでも**
`default-frame-alist` から `tab-bar-lines` を除けば正常だった。
したがって自動保存設定の変更は今回の回避策に含めない。

## 有力な原因仮説とEmacs本体の処理

`config/navigation.el` は `tab-bar-show=1`（タブが2つ以上のとき表示）を設定し、
`(tab-bar-mode 1)` を呼ぶ。

Emacs 31系の `lisp/tab-bar.el` では、
`tab-bar-mode` が `tab-bar--update-tab-bar-lines` を呼び、
`default-frame-alist` へ `(tab-bar-lines . 0)` を追加する。
`lisp/frame.el` の `frame-notice-user-settings` はユーザーの初期化後に
`default-frame-alist` を既存のTTYフレームへ適用する。

検証結果は、**タブバーの0行表示自体ではなく、起動時に
`default-frame-alist` から0行の設定を再適用する経路**が
クラッシュの発生条件に関係する、という仮説と整合する。

ただし `tty_write_glyphs_1` に至るCレベルの正確な原因は未特定。
Emacs 31.1本体の不具合と断定したり、Debianでも同じ症状になると
推定したりしないこと。

## 採用した回避策

`config/navigation.el` の `tab-bar` 用 `use-package` の `:config` 内で、
`(tab-bar-mode 1)` の**直後**に次を実行する。

```elisp
(setq default-frame-alist
      (assq-delete-all 'tab-bar-lines default-frame-alist))
```

これによって `tab-bar-mode` が設定した既定フレームパラメータのうち、
`tab-bar-lines` の項目**だけ**を取り除く。ほかのフレーム既定値は保持する。
現在のフレームのパラメータや `tab-bar-show` 自体は変更しない。

`default-frame-alist` を丸ごと消したり、
`frame-notice-user-settings` を無効にしたりする方法は、
ほかの初期化設定まで失うため採用しない。

### 採用前の確認コマンド

このコマンドで**元の自動保存設定を含む全設定**を読み込んでも、
Org本文の表示と `C-l` に成功した。さらに `M-x tab-new` で
2つ目のタブにタブバーが表示された。

```sh
emacs -q -nw \
  --eval '(package-initialize)' \
  -l ~/.emacs.d/init.el \
  --eval "(setq default-frame-alist
                (assq-delete-all 'tab-bar-lines default-frame-alist))" \
  /tmp/org-crash-test.org
```

※これは`init.el`の読込後に一時的に回避する検証コマンド。
実際の回避策は設定ファイル内の `tab-bar-mode` 呼び出し直後に置き、
Emacs標準の起動時フレーム初期化が実行される**前**に除外する。

## 残る確認事項・再発時の調査方針

- **設定変更後の通常起動** `emacs -nw /tmp/org-crash-test.org` と
  `C-l` による再描画は、実機で再検証すること。
  上記はあくまで`-q -l` による採用前の検証結果。
- タブを2個から1個に戻した際の自動非表示、新規フレーム作成、
  端末サイズ変更、DebianのTTYでの動作は未検証。
- 再発する場合は、起動時の `default-frame-alist` と
  `(frame-parameter nil 'tab-bar-lines)`、フレーム初期化の実行時点を
  記録し、LLDBのネイティブバックトレースを取得して比較する。
- TTY描画に関わるSegmentation faultなので、batch実行のERTだけでは
  この問題が修正されたという証拠にはならない。実TTYでの再現試験が必要。
- この回避策が将来不要になったかはEmacsの更新時に再評価する。
  原因未特定のため、安易に削除しないこと。

調査時の `/tmp/emacs-core-sha256.el` や `/tmp/emacs-init-sha256.el`
は切り分け用の一時ファイルであり、このリポジトリの設定ではない。
