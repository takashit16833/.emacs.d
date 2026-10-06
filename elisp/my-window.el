;;; my-window.el --- Window helpers -*- lexical-binding: t; -*-

;;; Commentary:
;; ウィンドウの配置や表示状態を操作する独自コマンドを定義する。

;;; Code:


;; 現在のウィンドウを最大化・復元する。
(defun my/toggle-window-zoom ()
  "現在のタブでウィンドウの最大化を切り替える。"
  (interactive)
  (let* ((tab (assq 'current-tab (tab-bar-tabs)))
         (saved (alist-get 'my/window-zoom (cdr tab))))
    (if saved
        (progn
          (set-window-configuration saved)
          (setf (alist-get 'my/window-zoom (cdr tab)) nil))
      (unless (one-window-p t)
        (setf (alist-get 'my/window-zoom (cdr tab))
              (current-window-configuration))
        (maximize-window)))))


(defun my/window--children (window)
  "WINDOW の子ウィンドウを表示順に返す。"
  (let ((child (window-child window))
        children)
    (while child
      (push child children)
      (setq child (window-next-sibling child)))
    (nreverse children)))


(defun my/window--snapshot-layout (window selected)
  "WINDOW 以下のレイアウトと状態を保存する。
SELECTED は現在選択中のウィンドウ。"
  (if (window-live-p window)
      (list :leaf t
            :buffer (window-buffer window)
            :start (window-start window)
            :point (window-point window)
            :hscroll (window-hscroll window)
            :vscroll (window-vscroll window)
            :prev-buffers (copy-tree (window-prev-buffers window))
            :next-buffers (copy-sequence (window-next-buffers window))
            :dedicated (window-dedicated-p window)
            :parameters (copy-tree (window-parameters window))
            :selected (eq window selected))
    (let* ((horizontal (window-left-child window))
           (children (my/window--children window)))
      (list :orientation (if horizontal 'horizontal 'vertical)
            :weights
            (mapcar
             (lambda (child)
               (window-total-size child horizontal))
             children)
            :children
            (mapcar
             (lambda (child)
               (my/window--snapshot-layout child selected))
             children)))))


(defun my/window--flip-layout (layout)
  "LAYOUT のすべての分割方向を縦横反転する。"
  (if (plist-get layout :leaf)
      layout
    (list :orientation
          (if (eq (plist-get layout :orientation) 'horizontal)
              'vertical
            'horizontal)
          :weights (plist-get layout :weights)
          :children
          (mapcar #'my/window--flip-layout
                  (plist-get layout :children)))))


(defun my/window--split-target (window orientation weights)
  "WINDOW を ORIENTATION と WEIGHTS に従って分割する。
作成した子ウィンドウを表示順に返す。"
  (let ((horizontal (eq orientation 'horizontal))
        (remaining-window window)
        (remaining-weight (apply #'+ weights))
        windows)
    (dolist (weight (butlast weights))
      (let* ((total (window-total-size remaining-window horizontal))
             (size (max 1
                        (min (1- total)
                             (round (* total weight)
                                    remaining-weight))))
             (new-window
              (split-window remaining-window
                            size
                            (if horizontal 'right 'below))))
        (push remaining-window windows)
        (setq remaining-window new-window
              remaining-weight (- remaining-weight weight))))
    (nreverse (cons remaining-window windows))))


(defun my/window--restore-leaf (state window)
  "STATE の表示状態を WINDOW に復元する。
STATE が選択中だったウィンドウなら WINDOW を返す。"
  ;; 強い dedicated 状態でもbufferを差し替えられるよう先に解除する。
  (set-window-dedicated-p window nil)
  (set-window-buffer window (plist-get state :buffer))
  (set-window-start window (plist-get state :start))
  (set-window-point window (plist-get state :point))
  (set-window-hscroll window (plist-get state :hscroll))
  (set-window-vscroll window (plist-get state :vscroll))
  (set-window-prev-buffers window (plist-get state :prev-buffers))
  (set-window-next-buffers window (plist-get state :next-buffers))

  ;; レイアウト構築中には不要な構造用parameterは引き継がない。
  (dolist (parameter (plist-get state :parameters))
    (unless (memq (car parameter)
                  '(clone-of window-atom window-side window-slot))
      (set-window-parameter window (car parameter) (cdr parameter))))

  (set-window-dedicated-p window (plist-get state :dedicated))
  (and (plist-get state :selected) window))


(defun my/window--restore-layout (layout window)
  "LAYOUT を WINDOW の領域へ復元する。
元々選択されていたウィンドウに対応する新しいウィンドウを返す。"
  (if (plist-get layout :leaf)
      (my/window--restore-leaf layout window)
    (let ((children (plist-get layout :children))
          (windows
           (my/window--split-target
            window
            (plist-get layout :orientation)
            (plist-get layout :weights)))
          selected)
      (while children
        (let ((restored
               (my/window--restore-layout
                (car children)
                (car windows))))
          (when restored
            (setq selected restored)))
        (setq children (cdr children)
              windows (cdr windows)))
      selected)))


(defun my/toggle-window-split-direction ()
  "通常のウィンドウ分割全体を左右と上下で反転する。
VS Code の Toggle Vertical/Horizontal Editor Layout と同様に、
入れ子になった分割も再帰的に反転する。"
  (interactive)
  (let* ((root (frame-root-window))
         (main (window-main-window))
         (windows (window-list nil 'no-minibuffer))
         (selected (selected-window)))
    (when (eq main selected)
      ;; window-main-window がliveなら分割されていない。
      (user-error "ウィンドウが分割されていません"))
    (unless (eq main root)
      (user-error "Side Windowを含む配置では使用できません"))
    (when (delq nil (mapcar #'window-atom-root windows))
      (user-error "Atomic Windowを含む配置では使用できません"))

    (let ((configuration (current-window-configuration))
          (layout
           (my/window--flip-layout
            (my/window--snapshot-layout root selected))))
      (condition-case err
          (let ((ignore-window-parameters t)
                ;; 同方向の連続した分割は同じ親へまとめる。
                (window-combination-limit nil))
            (delete-other-windows selected)
            (let ((new-selected
                   (my/window--restore-layout layout (selected-window))))
              (when new-selected
                (select-window new-selected))))
        (error
         (set-window-configuration configuration)
         (signal (car err) (cdr err))))))))


(provide 'my-window)

;;; my-window.el ends here
