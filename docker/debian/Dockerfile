FROM debian:trixie

ARG EMACS_VERSION=31.1
ARG LUA_LANGUAGE_SERVER_VERSION=3.19.1
ARG GHC_VERSION=9.6.7
ARG CABAL_VERSION=3.12.1.0
ARG HLS_VERSION=2.15.0.0
ARG FOURMOLU_VERSION=0.20.1.0
ARG INTELEPHENSE_VERSION=1.18.5
ARG TYPESCRIPT_LANGUAGE_SERVER_VERSION=5.3.0
ARG PYRIGHT_VERSION=1.1.414
ARG RUFF_VERSION=0.16.10
ARG PHP_CODESNIFFER_VERSION=4.0.4
ARG PHPCS_SHA256=4b010cd21d8bc8a17e2504792e3c77ef8259126f24caf7eafe7eddef1fa871e9
ARG PHPCBF_SHA256=0b3b8c5571543e94452f6edec0d7e924b287a64c13b73d8dcf3d25f0ee004948
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
       jq \
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
       nodejs \
       npm \
       php-cli \
       php-xml \
       python3 \
       python3-venv \
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

RUN curl -fsSLO "https://ftp.jaist.ac.jp/pub/GNU/emacs/emacs-${EMACS_VERSION}.tar.xz" \
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

# php-ts-modeが使用するTree-sitter grammarをインストールする。
RUN emacs --batch -Q \
      --eval "(require 'php-ts-mode)" \
      --eval "(dolist (lang '(html css javascript jsdoc php phpdoc)) (treesit-install-language-grammar lang \"/usr/local/lib\"))" \
    && ldconfig \
    && emacs --batch -Q \
      --eval "(dolist (lang '(html css javascript jsdoc php phpdoc)) (unless (treesit-language-available-p lang) (kill-emacs 1)))"

# typescript-ts-mode / tsx-ts-modeが使用するTree-sitter grammarをインストールする。
RUN emacs --batch -Q \
      --eval "(require 'typescript-ts-mode)" \
      --eval "(dolist (lang '(typescript tsx)) (treesit-install-language-grammar lang \"/usr/local/lib\"))" \
    && ldconfig \
    && emacs --batch -Q \
      --eval "(dolist (lang '(typescript tsx)) (unless (treesit-language-available-p lang) (kill-emacs 1)))"

# python-ts-modeが使用するTree-sitter grammarをインストールする。
RUN emacs --batch -Q \
      --eval "(require 'python)" \
      --eval "(treesit-install-language-grammar 'python \"/usr/local/lib\")" \
    && ldconfig \
    && emacs --batch -Q \
      --eval "(unless (treesit-language-available-p 'python) (kill-emacs 1))"

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

# PHP Language ServerとしてIntelephenseをインストールする。
RUN npm install --global --no-audit --no-fund "intelephense@${INTELEPHENSE_VERSION}" \
    && command -v intelephense \
    && npm cache clean --force

# Debian trixieのNode.js 20で動作するTypeScript Language Serverをインストールする。
RUN npm install --global --no-audit --no-fund \
      "typescript-language-server@${TYPESCRIPT_LANGUAGE_SERVER_VERSION}" \
    && typescript-language-server --version \
    && npm cache clean --force

# Python Language ServerとしてPyrightをインストールする。
RUN npm install --global --no-audit --no-fund "pyright@${PYRIGHT_VERSION}" \
    && pyright --version \
    && command -v pyright-langserver \
    && npm cache clean --force

# Apheleiaが使用するRuffをインストールする。
RUN set -eux; \
    case "$(dpkg --print-architecture)" in \
      amd64) \
        ruff_arch=x86_64; \
        ruff_sha256=9567ff1201e2fb3da31ff04c35587d768c66d6cb42dfa84de474e2bfe360b608 \
        ;; \
      arm64) \
        ruff_arch=aarch64; \
        ruff_sha256=dc0d74de837ef0a7bcc62ce98c48a622b075d057161f13b958be2934becd55a6 \
        ;; \
      *) echo "Unsupported architecture: $(dpkg --print-architecture)" >&2; exit 1 ;; \
    esac; \
    archive="ruff-${ruff_arch}-unknown-linux-gnu.tar.gz"; \
    curl -fsSLO \
      "https://github.com/astral-sh/ruff/releases/download/${RUFF_VERSION}/${archive}"; \
    printf '%s  %s\n' "${ruff_sha256}" "${archive}" | sha256sum -c -; \
    tar -xzf "${archive}"; \
    install -m 0755 \
      "ruff-${ruff_arch}-unknown-linux-gnu/ruff" \
      /usr/local/bin/ruff; \
    ruff --version; \
    rm -rf "${archive}" "ruff-${ruff_arch}-unknown-linux-gnu"

# Apheleiaが使用するPHPCBFと、確認用のPHPCSをインストールする。
RUN curl -fsSL \
      "https://github.com/PHPCSStandards/PHP_CodeSniffer/releases/download/${PHP_CODESNIFFER_VERSION}/phpcs.phar" \
      -o /usr/local/bin/phpcs \
    && printf '%s  %s\n' "${PHPCS_SHA256}" /usr/local/bin/phpcs | sha256sum -c - \
    && curl -fsSL \
      "https://github.com/PHPCSStandards/PHP_CodeSniffer/releases/download/${PHP_CODESNIFFER_VERSION}/phpcbf.phar" \
      -o /usr/local/bin/phpcbf \
    && printf '%s  %s\n' "${PHPCBF_SHA256}" /usr/local/bin/phpcbf | sha256sum -c - \
    && chmod +x /usr/local/bin/phpcs /usr/local/bin/phpcbf \
    && phpcs --version \
    && phpcbf --version

# Haskell Language Serverが対応しているGHCとCabalをGHCupでインストールする。
RUN curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org \
      | BOOTSTRAP_HASKELL_NONINTERACTIVE=1 \
        BOOTSTRAP_HASKELL_MINIMAL=1 \
        sh \
    && ghcup --url-source="${GHCUP_METADATA_URL}" install ghc "${GHC_VERSION}" \
    && ghcup set ghc "${GHC_VERSION}" \
    && ghcup --url-source="${GHCUP_METADATA_URL}" install cabal "${CABAL_VERSION}" \
    && cabal update \
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

# 実プロジェクトと同様にTypeScriptとPrettierはプロジェクトローカルへ入れる。
RUN cd /workspace/typescript-lsp-test \
    && npm install --no-audit --no-fund \
    && ./node_modules/.bin/tsc --version \
    && ./node_modules/.bin/prettier --version

RUN git -C /workspace/lua-lsp-test init -q \
    && git -C /workspace/haskell-lsp-test init -q \
    && git -C /workspace/php-lsp-test init -q \
    && git -C /workspace/python-lsp-test init -q \
    && git -C /workspace/typescript-lsp-test init -q

COPY entrypoint.sh /usr/local/bin/emacs-debian-entrypoint

# コンテナ内では `e` でTTY版Emacsを起動できるようにする。
RUN printf '%s\n' '#!/bin/sh' 'exec emacs -nw "$@"' > /usr/local/bin/e \
    && chmod +x /usr/local/bin/e /usr/local/bin/emacs-debian-entrypoint

ENTRYPOINT ["/usr/local/bin/emacs-debian-entrypoint"]
