#!/bin/sh
set -eu

exec env \
  LANG=C.UTF-8 \
  TERM=xterm-256color \
  COLORTERM=truecolor \
  emacs -nw "$@"
