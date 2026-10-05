FROM debian:trixie

ARG EMACS_VERSION=31.1
ARG LUA_LANGUAGE_SERVER_VERSION=3.19.1
ARG GHC_VERSION=9.6.7
ARG CABAL_VERSION=3.12.1.0
ARG HLS_VERSION=2.15.0.0
ARG FOURMOLU_VERSION=0.20.1.0
ARG HASKELL_TREE_SITTER_REV=f3fd0ad1e47aa0ff590479afb1f3e8275e4381cb
ARG GHCUP_METADATA_URL=https://raw.githubusercontent.com/haskell/ghcup-metadata/master/ghcup-vanilla-0.1.0.yaml

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV TERM=xterm-256color
ENV COLORTERM=truecolor
ENV PATH=/root/.ghcup/bin:${PATH}

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       build-essential \
       ca-certificates \
       cmake \
       curl \
       gh \
       git \
       libffi-dev \
       libgccjit-14-dev \
       libgmp-dev \
       libgnutls28-dev \
       libncurses-dev \
       libnuma-dev \
       libsqlite3-dev \
       libtool-bin \
       libtree-sitter-dev \
       libvterm-dev \
       libxml2-dev \
       pkg-config \
       ripgrep \
       rsync \
       texinfo \
       tree-sitter-cli \
       unzip \
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

# haskell-ts-modeが要求するTree-sitter grammarをインストールする。
# 公式grammarではなくhaskell-ts-mode作者のforkを使用する。
RUN git clone -q https://github.com/dschrempf/tree-sitter-haskell.git /tmp/tree-sitter-haskell \
    && git -C /tmp/tree-sitter-haskell checkout -q "${HASKELL_TREE_SITTER_REV}" \
    && cd /tmp/tree-sitter-haskell \
    && tree-sitter generate src/grammar.json --abi=14 \
    && cc -std=c11 -fPIC -Isrc -c src/parser.c -o parser.o \
    && cc -std=c11 -fPIC -Isrc -c src/scanner.c -o scanner.o \
    && cc -shared parser.o scanner.o -o /usr/local/lib/libtree-sitter-haskell.so \
    && ldconfig \
    && emacs --batch -Q \
      --eval "(unless (treesit-language-available-p 'haskell) (kill-emacs 1))" \
    && rm -rf /tmp/tree-sitter-haskell

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

# Haskell Language Serverが対応しているGHCとCabalをGHCupでインストールする。
RUN curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org \
      | BOOTSTRAP_HASKELL_NONINTERACTIVE=1 \
        BOOTSTRAP_HASKELL_MINIMAL=1 \
        sh \
    && ghcup --url-source="${GHCUP_METADATA_URL}" install ghc "${GHC_VERSION}" \
    && ghcup set ghc "${GHC_VERSION}" \
    && ghcup --url-source="${GHCUP_METADATA_URL}" install cabal "${CABAL_VERSION}" \
    && ghcup --url-source="${GHCUP_METADATA_URL}" install hls "${HLS_VERSION}" \
    && ghc --version \
    && cabal --version \
    && haskell-language-server-wrapper --version

# ApheleiaとHLSの両方から使うFourmoluをインストールする。
RUN set -eux; \
    case "$(dpkg --print-architecture)" in \
      amd64) \
        fourmolu_arch=x86_64; \
        fourmolu_sha256=bdd97063b445145b39191259c428bca489fa30578b82d9066fc7377db390f1d0 \
        ;; \
      arm64) \
        fourmolu_arch=arm64; \
        fourmolu_sha256=56ad7ae69b4bff12d4144ae86fdfec2cab16a19e29f76fd316c491a986c0c335 \
        ;; \
      *) echo "Unsupported architecture: $(dpkg --print-architecture)" >&2; exit 1 ;; \
    esac; \
    archive="fourmolu-${FOURMOLU_VERSION}-linux-${fourmolu_arch}.zip"; \
    curl -fsSLO \
      "https://github.com/fourmolu/fourmolu/releases/download/v${FOURMOLU_VERSION}/${archive}"; \
    printf '%s  %s\n' "${fourmolu_sha256}" "${archive}" | sha256sum -c -; \
    unzip -q "${archive}" -d /tmp/fourmolu; \
    install -m 0755 \
      "/tmp/fourmolu/fourmolu-${FOURMOLU_VERSION}-linux-${fourmolu_arch}/fourmolu" \
      /usr/local/bin/fourmolu; \
    fourmolu --version; \
    rm -rf "${archive}" /tmp/fourmolu

# LSPの動作確認に使う小さなプロジェクトを配置する。
COPY workspace /workspace

RUN git -C /workspace/lua-lsp-test init -q \
    && git -C /workspace/haskell-lsp-test init -q

COPY entrypoint.sh /usr/local/bin/emacs-debian-entrypoint

RUN chmod +x /usr/local/bin/emacs-debian-entrypoint

ENTRYPOINT ["/usr/local/bin/emacs-debian-entrypoint"]
