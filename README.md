Nice, let’s build you a “batteries-included” dev image.

This gives you:

* **Base**: `lscr.io/linuxserver/code-server:latest` ([LinuxServer.io][1])
* **Python** via **pyenv**: `3.12.12` (default) + `3.11.14` installed ([Python.org][2])
* **Node.js** via **nvm**: latest LTS **24.x “Krypton”** (e.g. `24.11.1`) as default ([Node.js][3])
* **System build deps** so `pip install` (and native Node modules) almost never fail.

---

## Dockerfile (production-ish but dev-friendly)

```dockerfile
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
    curl \
    git \
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
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------
# 2. pyenv (global install) + Python 3.12/3.11
# ------------------------------------------------------------

# Versions to preinstall
ARG PYTHON_3_12_VERSION=3.12.12
ARG PYTHON_3_11_VERSION=3.11.14

ENV PYENV_ROOT=/usr/local/pyenv
ENV PATH="$PYENV_ROOT/shims:$PYENV_ROOT/bin:$PATH"

# Install pyenv
RUN git clone https://github.com/pyenv/pyenv.git "$PYENV_ROOT" \
 && mkdir -p $PYENV_ROOT/plugins \
 && chmod -R a+rX $PYENV_ROOT \
 && find $PYENV_ROOT -type d -print0 | xargs -0 chmod a+rx

# Install Python versions via pyenv and set 3.12 as global default
RUN bash -lc " \
    pyenv install ${PYTHON_3_12_VERSION} && \
    pyenv install ${PYTHON_3_11_VERSION} && \
    pyenv global ${PYTHON_3_12_VERSION} && \
    pyenv rehash \
" \
 # convenience symlinks for tooling that expects /usr/local/bin/python/pip
 && ln -sf $PYENV_ROOT/shims/python /usr/local/bin/python \
 && ln -sf $PYENV_ROOT/shims/pip /usr/local/bin/pip

# Make pyenv automatically available in interactive shells
RUN echo 'export PYENV_ROOT=/usr/local/pyenv' > /etc/profile.d/pyenv.sh \
 && echo 'export PATH="$PYENV_ROOT/shims:$PYENV_ROOT/bin:$PATH"' >> /etc/profile.d/pyenv.sh \
 && echo 'eval "$(pyenv init -)"' >> /etc/profile.d/pyenv.sh

# ------------------------------------------------------------
# 3. nvm + Node.js latest LTS (24.x Krypton)
# ------------------------------------------------------------

# nvm prefers being in NVM_DIR; install globally under /usr/local
ENV NVM_DIR=/usr/local/nvm
RUN mkdir -p "$NVM_DIR" \
 && curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash \
    --no-use \
 && chmod -R a+rwx "$NVM_DIR"

# Node LTS to preinstall (24.x Krypton)
ARG NODE_LTS_VERSION=24.11.1

# Install Node LTS via nvm and make it the default + global symlinks
RUN bash -lc " \
    export NVM_DIR=/usr/local/nvm; \
    . \"$NVM_DIR/nvm.sh\"; \
    nvm install ${NODE_LTS_VERSION}; \
    nvm alias default ${NODE_LTS_VERSION}; \
    node_path=\"\$(nvm which default)\"; \
    # Symlink default Node to /usr/local/bin for non-login shells
    ln -sf \"\$node_path\" /usr/local/bin/node; \
    ln -sf \"\$(dirname \"\$node_path\")/npm\" /usr/local/bin/npm; \
    ln -sf \"\$(dirname \"\$node_path\")/npx\" /usr/local/bin/npx \
"

# Auto-load nvm for interactive shells inside the container
RUN echo 'export NVM_DIR=/usr/local/nvm' > /etc/profile.d/nvm.sh \
 && echo '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"' >> /etc/profile.d/nvm.sh

# ------------------------------------------------------------
# 4. Nice-to-have defaults
# ------------------------------------------------------------

# Make sure /config/workspace exists as the default workspace
RUN mkdir -p /config/workspace

# (Optional) Set some sensible git defaults for the container user later
# You can mount ~/.gitconfig via volume, or configure from terminal.
```

---

## docker-compose example

```yaml
version: "3.8"

services:
  code-server:
    image: my-org/code-server-dev:latest   # <-- build from the Dockerfile above
    container_name: code-server-dev
    environment:
      - PUID=1000           # adjust for your host user
      - PGID=1000
      - TZ=Etc/UTC
      - PASSWORD=changeme   # or HASHED_PASSWORD
      - SUDO_PASSWORD=changeme  # if you want sudo inside terminal
      - DEFAULT_WORKSPACE=/config/workspace
    volumes:
      - ./config:/config
      - ./projects:/config/workspace
    ports:
      - "8443:8443"
    restart: unless-stopped
```

(Env vars/volumes are the same as the official docs, just pointing to your custom image. ([LinuxServer.io][1]))

---

## How you actually *use* it inside code-server

Open the **Terminal** from the code-server UI:

### Python

```bash
python --version
# Python 3.12.12

pyenv versions
# * 3.12.12 (set by /usr/local/pyenv/version)
#   3.11.14

# Switch globally inside the container
pyenv global 3.11.14
python --version  # now 3.11.14
```

If you want per-project versions:

```bash
cd /config/workspace/my-project
pyenv local 3.11.14
```

### Node.js

```bash
node -v        # v24.11.1 (LTS)
npm -v
npx -v

# Use nvm interactively
. /etc/profile.d/nvm.sh   # usually already loaded in login shells
nvm ls
nvm install 22
nvm use 22
```

> Because we symlinked the default Node to `/usr/local/bin/node`, everything works even in non-login shells, but you still have the full `nvm` workflow available in the terminal.

---

If you tell me what languages/frameworks you’ll use (e.g. Django, FastAPI, React, Next.js), I can add a small layer on top of this with preinstalled global tools (like `pipx`, `uv`, `pnpm`, `yarn`, eslint, etc.) tuned to your stack.

[1]: https://docs.linuxserver.io/images/docker-code-server/ "code-server - LinuxServer.io"
[2]: https://www.python.org/doc/versions/?utm_source=chatgpt.com "Python documentation by version"
[3]: https://nodejs.org/en/blog/release/v24.11.0?utm_source=chatgpt.com "Node.js v24.11.0 (LTS)"
