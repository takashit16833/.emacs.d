;;; org-pomodoro.el --- Org Pomodoro configuration -*- lexical-binding: t; -*-

;;; Commentary:
;; Org Pomodoroの時間、記録、通知音を設定する。

;;; Code:

(use-package org-pomodoro
  :ensure t
  :commands (org-pomodoro)
  :custom
  ;; 集中25分、短い休憩5分、4回ごとに長い休憩15分。
  (org-pomodoro-length 25)
  (org-pomodoro-short-break-length 5)
  (org-pomodoro-long-break-length 15)
  (org-pomodoro-long-break-frequency 4)

  ;; 集中終了後は自動で休憩し、次の集中は手動で開始する。
  (org-pomodoro-manual-break nil)

  ;; 休憩時間はCLOCKに記録せず、途中終了した作業時間は残す。
  (org-pomodoro-clock-break nil)
  (org-pomodoro-keep-killed-pomodoro-time t)

  ;; 開始・終了などの通知音を有効にする。
  (org-pomodoro-play-sounds t)

  ;; macOSではafplay、Debian系Linuxではaplayを使用する。
  ;; どちらもなければorg-pomodoro標準と同様に外部再生を行わない。
  (org-pomodoro-audio-player
   (or (executable-find "afplay")
       (executable-find "aplay")))

  ;; 集中終了時と休憩終了時の通知音。
  (org-pomodoro-finished-sound
   (expand-file-name "sounds/pomodoro-focus-finished.wav"
                     user-emacs-directory))
  (org-pomodoro-short-break-sound
   (expand-file-name "sounds/pomodoro-break-finished.wav"
                     user-emacs-directory))
  (org-pomodoro-long-break-sound
   (expand-file-name "sounds/pomodoro-break-finished.wav"
                     user-emacs-directory)))


;;; org-pomodoro.el ends here
