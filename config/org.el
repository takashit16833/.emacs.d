;;; org.el --- Org configuration -*- lexical-binding: t; -*-
;;; Commentary:
;; Org に関する設定。

;;; Code:

;; Orgファイルの保存先。
(setq org-directory (expand-file-name "~/org/"))
(setq org-default-notes-file
      (expand-file-name "notes.org" org-directory))


(use-package org
  :ensure nil
  :hook (org-mode . org-indent-mode)
  :custom
  ;; *bold* や /italic/ の記号を通常時は隠す。
  (org-hide-emphasis-markers t)

  ;; 見出しが1段深くなるごとに1文字分インデントする。
  (org-indent-indentation-per-level 1)

  (org-tag-alist
   '(("emacs" . ?e)
     ("rag_lab" . ?r)))
  :bind
  (("C-c o c" . org-capture)
   ("C-c o a" . org-agenda)))


;; Org のブロック種類別配色（標準ブロック描画の後に適用）。
(require 'my-org-block-colors)

;; 優先度別の face。配色はテーマ側で指定し、他のテーマでは標準の装飾を継承する。
(defface my/org-modern-priority-a
  '((t :inherit org-modern-priority))
  "Org の優先度 A に使う face。"
  :group 'org)

(defface my/org-modern-priority-b
  '((t :inherit org-modern-priority))
  "Org の優先度 B に使う face。"
  :group 'org)

(defface my/org-modern-priority-c
  '((t :inherit org-modern-priority))
  "Org の優先度 C に使う face。"
  :group 'org)

;; Orgの表示を見やすく整える。
(use-package org-modern
  :ensure t
  :custom
  ;; ============================================================
  ;; 見出し
  ;; ============================================================

  ;; 見出し先頭の「*」の表示方法。
  ;; nil: 変更しない / fold: 開閉記号 / replace: レベル別の記号
  (org-modern-star 'replace)

  ;; 見出し先頭の余分な「*」の表示方法。
  ;; nil: そのまま / t: 非表示 / leading: 非表示にして幅も詰める
  ;; 文字や文字列を指定すると、その記号に置き換える。
  (org-modern-hide-stars 'leading)

  ;; 見出し記号だけを紫にして、見出し文字と区別する。
  (org-modern-replace-stars
   (mapcar (lambda (symbol)
             (propertize (char-to-string symbol)
                         'face '(:foreground "#7CBEFF")))
           (string-to-list "󰎤󰎧󰎪󰎭󰎱󰎳󰎶󰎹")))

  ;; fold使用時に表示する記号。
  ;; 各組の左側が閉じた状態、右側が開いた状態。
  (org-modern-fold-stars
   '(("▶" . "▼")
     ("▷" . "▽")
     ("⯈" . "⯆")
     ("▹" . "▿")
     ("▸" . "▾")))

  ;; 見出しレベルが記号の種類を超えた場合の動作。
  ;; nil: 最後の記号を使用 / t: 最初から繰り返す
  (org-modern-cycle-stars nil)

  ;; ============================================================
  ;; TODO・優先度・タグ
  ;; ============================================================

  ;; TODO・DONEをラベル風に装飾する。
  (org-modern-todo t)

  ;; TODO・DONEごとの色を指定する。
  ;; nil: 個別指定なし / 対応表: 状態ごとに色を指定
  (org-modern-todo-faces nil)

  ;; 優先度「[#A]」などを装飾する。
  ;; nil: 無効 / t: 標準装飾 / 対応表: 任意の記号に置換
  (org-modern-priority t)

  ;; 優先度 A/B/C を別々の face に割り当て、色はテーマ側で管理する。
  (org-modern-priority-faces
   '((?A . my/org-modern-priority-a)
     (?B . my/org-modern-priority-b)
     (?C . my/org-modern-priority-c)))

  ;; 見出しのタグ「:emacs:」などをラベル風に装飾する。
  (org-modern-tag t)

  ;; タグごとの色を指定する。
  ;; nil: 個別指定なし / 対応表: タグごとに色を指定
  (org-modern-tag-faces nil)

  ;; ============================================================
  ;; 日付
  ;; ============================================================

  ;; 日付・時刻をラベル風に装飾する。
  ;; nil: 無効 / t: 標準装飾 / 書式の組: 表示形式を指定
  (org-modern-timestamp t)

  ;; ============================================================
  ;; リスト・チェックボックス
  ;; ============================================================

  ;; 箇条書きの先頭記号を置き換える。
  ;; nil: 変更しない / 対応表: 元の記号と表示する記号を指定
  (org-modern-list
   '((?+ . "◦")
     (?- . "–")
     (?* . "•")))

  ;; チェックボックスを状態に応じた記号に置き換える。
  ;; nil: 変更しない / 対応表: 状態ごとの記号を指定
  (org-modern-checkbox nil)
  
  ;; ============================================================
  ;; 表
  ;; ============================================================

  ;; Orgの表を装飾する。
  ;; nil: 無効 / t: 有効
  (org-modern-table nil)

  ;; 表の縦線の幅をピクセル単位で指定する。
  ;; nil: 縦線なし / 非負整数: 線の幅
  ;; CLIではピクセル単位の幅を正確に表現できない。
  (org-modern-table-vertical 0.1)

  ;; 表の横線の装飾を指定する。
  ;; nil: 無効 / 数値: 横線の装飾
  ;; CLIでは文字の高さを細かく変更できない。
  (org-modern-table-horizontal 0.1)

  ;; ============================================================
  ;; ブロック
  ;; ============================================================

  ;; 「#+begin_src」などのブロック名を装飾する。
  ;; nil: 無効 / t: 接頭部分を隠す / 文字列の組: 置換
  (org-modern-block-name t)

  ;; ブロック左側に境界線を表示する。
  ;; nil: 無効 / t: 有効 / 整数: 境界線の位置
  ;; CLIではGUI用の左余白を表示できないため無効化。
  (org-modern-block-fringe nil)

  ;; ============================================================
  ;; メタ情報
  ;; ============================================================

  ;; 「#+TITLE:」などのキーワードを装飾する。
  ;; nil: 無効 / t:「#+」を隠す / 文字列: 置換
  (org-modern-keyword t)

  ;; ============================================================
  ;; その他
  ;; ============================================================

  ;; 「-----」などの水平線を装飾する。
  ;; nil: 無効 / t: 装飾 / 文字列: 指定した表示に置換
  (org-modern-horizontal-rule t)

  ;; 脚注の定義部分と参照部分の表示形式を指定する。
  ;; nil: 無効 / 組: 定義と参照それぞれの表示方法
  (org-modern-footnote
   (cons nil (cadr org-script-display)))

  ;; 進捗「[3/5]」などを棒状に装飾する。
  ;; nil: 無効 / 非負整数: 棒の幅（文字数）
  (org-modern-progress 12)

  ;; 内部リンク先「<<target>>」の表示形式。
  ;; nil: 無効 / リスト: 前後の記号と本文の表示方法
  (org-modern-internal-target '(" ↪ " t " "))

  ;; 自動リンク対象「<<<target>>>」の表示形式。
  ;; nil: 無効 / リスト: 前後の記号と本文の表示方法
  (org-modern-radio-target '(" ⛯ " t " "))

  ;; TODO・タグなどのラベル枠の太さを指定する。
  ;; nil: 既定幅 / 整数: ピクセル / 小数: 文字高さに対する割合
  ;; CLIではピクセル単位の枠線を表現できないため無効化。
  (org-modern-label-border nil)

  :hook (org-mode . org-modern-mode))


(setq org-agenda-files
      (list org-default-notes-file))


;;; org.el ends here
