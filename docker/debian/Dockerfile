FROM debian:trixie

ARG EMACS_VERSION=31.1

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

COPY entrypoint.sh /usr/local/bin/emacs-debian-entrypoint

RUN chmod +x /usr/local/bin/emacs-debian-entrypoint

ENTRYPOINT ["/usr/local/bin/emacs-debian-entrypoint"]
