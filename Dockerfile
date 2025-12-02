# Base: LinuxServer.io code-server image (Ubuntu LTS + s6-overlay)
FROM lscr.io/linuxserver/code-server:latest

ENV DEBIAN_FRONTEND=noninteractive

# ------------------------------------------------------------
# 1. Core build toolchain + libraries for Python & Node builds
# ------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    # toolchain
    build-essential \
    make \
    g++ \
    rustc \
    cargo \
    cmake \
    curl \
    git \
    git-lfs \
    wget \
    pkg-config \
    ca-certificates \
    # python build deps (for pyenv + manywheel packages)
    zlib1g-dev \
    libssl-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    libffi-dev \
    liblzma-dev \
    uuid-dev \
    libncurses5-dev \
    libncursesw5-dev \
    xz-utils \
    # common native deps for popular Python libs (Pillow, lxml, db drivers, etc.)
    libjpeg-dev \
    libpng-dev \
    libfreetype-dev \
    libxml2-dev \
    libxslt1-dev \
    libpq-dev \
    default-libmysqlclient-dev \
    libsodium-dev \
    libnacl-dev \
    # handy CLI tools
    ripgrep \
    fd-find \
    jq \
    ffmpeg \
    s3cmd \
    # networking + diagnostics
    iputils-ping \
    netcat-openbsd \
    rsync \
    htop \
    vim \
    traceroute \
    iperf3 \
    nmap \
    ncdu \
    sysstat \
    zip \
    unzip \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------
# 2. pyenv (global install) + Python 3.12/3.11
# ------------------------------------------------------------

# Versions to preinstall (you can adjust these)
ARG PYTHON_3_12_VERSION=3.12.5
ARG PYTHON_3_11_VERSION=3.11.9

ENV PYENV_ROOT=/usr/local/pyenv
ENV PATH="$PYENV_ROOT/shims:$PYENV_ROOT/bin:$PATH"

# Install pyenv
RUN git clone https://github.com/pyenv/pyenv.git "$PYENV_ROOT" \
 && mkdir -p "$PYENV_ROOT/plugins" \
 && chmod -R a+rX "$PYENV_ROOT" \
 && find "$PYENV_ROOT" -type d -print0 | xargs -0 chmod a+rx

# Install Python versions via pyenv and set 3.12 as global default
RUN bash -lc " \
    pyenv install ${PYTHON_3_12_VERSION} && \
    pyenv install ${PYTHON_3_11_VERSION} && \
    pyenv global ${PYTHON_3_12_VERSION} && \
    pyenv rehash \
" \
 && ln -sf "$PYENV_ROOT/shims/python" /usr/local/bin/python \
 && ln -sf "$PYENV_ROOT/shims/pip" /usr/local/bin/pip

# Make pyenv automatically available in interactive shells
RUN echo 'export PYENV_ROOT=/usr/local/pyenv' > /etc/profile.d/pyenv.sh \
 && echo 'export PATH="$PYENV_ROOT/shims:$PYENV_ROOT/bin:$PATH"' >> /etc/profile.d/pyenv.sh \
 && echo 'eval "$(pyenv init -)"' >> /etc/profile.d/pyenv.sh

# ------------------------------------------------------------
# 3. nvm + Node.js latest LTS
# ------------------------------------------------------------

ENV NVM_DIR=/usr/local/nvm

# Install nvm
RUN mkdir -p "$NVM_DIR" \
 && curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh \
    | NVM_DIR="$NVM_DIR" bash \
 && chmod -R a+rwx "$NVM_DIR"

# Install Node LTS via nvm and make it default + global symlinks
RUN bash -lc " \
    export NVM_DIR=/usr/local/nvm; \
    . \"$NVM_DIR/nvm.sh\"; \
    nvm install --lts; \
    nvm alias default 'lts/*'; \
    node_path=\"\$(nvm which default)\"; \
    ln -sf \"\$node_path\" /usr/local/bin/node; \
    ln -sf \"\$(dirname \"\$node_path\")/npm\" /usr/local/bin/npm; \
    ln -sf \"\$(dirname \"\$node_path\")/npx\" /usr/local/bin/npx \
"

# Auto-load nvm for interactive shells inside the container
RUN echo 'export NVM_DIR=/usr/local/nvm' > /etc/profile.d/nvm.sh \
 && echo '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"' >> /etc/profile.d/nvm.sh

# ------------------------------------------------------------
# 4. Default workspace directory
# ------------------------------------------------------------

RUN mkdir -p /config/workspace
