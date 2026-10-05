FROM debian:trixie

ARG EMACS_VERSION=31.1
ARG LUA_LANGUAGE_SERVER_VERSION=3.19.1

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV TERM=xterm-256color
ENV COLORTERM=truecolor

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       build-essential \
       ca-certificates \
       cmake \
       curl \
       gh \
       git \
       libgccjit-14-dev \
       libgmp-dev \
       libgnutls28-dev \
       libncurses-dev \
       libsqlite3-dev \
       libtool-bin \
       libtree-sitter-dev \
       libvterm-dev \
       libxml2-dev \
       pkg-config \
       ripgrep \
       rsync \
       texinfo \
       xz-utils \
       zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp

RUN curl -fsSLO "https://ftp.gnu.org/gnu/emacs/emacs-${EMACS_VERSION}.tar.xz" \
    && tar -xf "emacs-${EMACS_VERSION}.tar.xz" \
    && cd "emacs-${EMACS_VERSION}" \
    && ./configure \
       --without-x \
       --with-native-compilation=aot \
       --with-tree-sitter \
       --with-sqlite3 \
       --with-gnutls \
       --with-modules \
    && make -j"$(nproc)" \
    && make install \
    && emacs --version | head -n 1 \
    && cd / \
    && rm -rf "/tmp/emacs-${EMACS_VERSION}" "/tmp/emacs-${EMACS_VERSION}.tar.xz"

# lua-ts-modeが使用するLuaのTree-sitter grammarをインストールする。
RUN emacs --batch -Q \
      --eval "(require 'lua-ts-mode)" \
      --eval "(treesit-install-language-grammar 'lua \"/usr/local/lib\")" \
    && ldconfig \
    && emacs --batch -Q \
      --eval "(require 'lua-ts-mode)" \
      --eval "(unless (treesit-language-available-p 'lua) (kill-emacs 1))"

# Lua Language Serverをインストールする。
RUN set -eux; \
    case "$(dpkg --print-architecture)" in \
      amd64) lua_ls_arch=x64 ;; \
      arm64) lua_ls_arch=arm64 ;; \
      *) echo "Unsupported architecture: $(dpkg --print-architecture)" >&2; exit 1 ;; \
    esac; \
    mkdir -p /opt/lua-language-server; \
    curl -fsSL \
      "https://github.com/LuaLS/lua-language-server/releases/download/${LUA_LANGUAGE_SERVER_VERSION}/lua-language-server-${LUA_LANGUAGE_SERVER_VERSION}-linux-${lua_ls_arch}.tar.gz" \
      | tar -xz -C /opt/lua-language-server; \
    printf '%s\n' \
      '#!/bin/sh' \
      'exec /opt/lua-language-server/bin/lua-language-server "$@"' \
      > /usr/local/bin/lua-language-server; \
    chmod +x /usr/local/bin/lua-language-server; \
    lua-language-server --version

# LSPの動作確認に使う小さなLuaプロジェクトを配置する。
COPY workspace /workspace

RUN git -C /workspace/lua-lsp-test init -q

COPY entrypoint.sh /usr/local/bin/emacs-debian-entrypoint

RUN chmod +x /usr/local/bin/emacs-debian-entrypoint

ENTRYPOINT ["/usr/local/bin/emacs-debian-entrypoint"]
