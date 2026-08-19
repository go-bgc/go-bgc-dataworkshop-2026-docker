ARG BASE_CONTAINER=quay.io/jupyter/r-notebook:hub-5.4.6
# Based on docker-stacks images at https://github.com/jupyter/docker-stacks/blob/main/images/r-notebook/Dockerfile
# Ubuntu 24.04 (noble)

FROM $BASE_CONTAINER

LABEL maintainer="Wing-Ho Ko <wingho@uw.edu>"

# install rstudio-server
USER root

# Copy package install lists
COPY --chown=$NB_UID: apt.txt /home/jovyan/

# Per: https://posit.co/download/rstudio-server/
RUN apt-get update --fix-missing > /dev/null && \
    apt-get upgrade --yes && \
    xargs -a apt.txt apt-get install --yes && \
    curl --silent -L --fail wget https://download2.rstudio.org/server/jammy/amd64/rstudio-server-2026.07.1-147-amd64.deb > /tmp/rstudio.deb && \
    gdebi -n /tmp/rstudio.deb && \
    rm /tmp/rstudio.deb && \
    apt-get clean > /dev/null && \
    rm -rf /var/lib/apt/lists/*

# Needed for libncurses5 package
RUN echo "deb http://security.ubuntu.com/ubuntu focal-security main universe" > /etc/apt/sources.list.d/ubuntu-focal-sources.list

# Install libncurses5 package
RUN apt-get update --fix-missing > /dev/null && apt-get install --yes libncurses5

# Fix for error: "System has not been booted with systemd as init system (PID 1)" related to timedatectl running in containers.
RUN echo 'TZ="America/Los_Angeles"' >> /opt/conda/lib/R/etc/Renviron

# make RStudio server runnable from command line
ENV PATH=$PATH:/usr/lib/rstudio-server/bin

# Make RStudio server runnable for the standard user (jovyan)
RUN echo "rsession-ld-library-path=/opt/conda/lib" >> /etc/rstudio/rserver.conf \
    && echo "server-user=$NB_USER" >> /etc/rstudio/rserver.conf

# Make RStudio server runnable for the standard user (jovyan)
RUN mkdir -p /var/run/rstudio-server /var/lib/rstudio-server \
    && chown -R $NB_USER:$NB_GID /var/run/rstudio-server /var/lib/rstudio-server \
    && chmod -R 775 /var/run/rstudio-server /var/lib/rstudio-server

# Add wrapper for gitpuller
COPY --chmod=755 safe_gitpuller.sh /usr/local/bin/safe_gitpuller

# make Amazon cli available
ENV PATH="/home/$NB_USER/.local/bin:${PATH}"

# set the python used by reticulate
ENV RETICULATE_PYTHON="/opt/conda/bin/python"

# Copy stdin-fixing script to image (not mounted volume)
COPY --chmod=755 inject-env.py /usr/local/bin/fix-stdin.py

# Create a Jupyter startup script in a system location (not shadowed by user volume mount)
RUN mkdir -p /usr/local/etc/jupyter/startup && \
    echo '#!/usr/bin/env python3' > /usr/local/etc/jupyter/startup/00-fix-stdin.py && \
    cat /usr/local/bin/fix-stdin.py | tail -n +2 >> /usr/local/etc/jupyter/startup/00-fix-stdin.py && \
    chmod +x /usr/local/etc/jupyter/startup/00-fix-stdin.py.py

# Copy environment variable injection script to image (not mounted volume)
COPY --chmod=755 inject-env.py /usr/local/bin/inject-env.py

# Create a Jupyter startup script in a system location (not shadowed by user volume mount)
RUN mkdir -p /usr/local/etc/jupyter/startup && \
    echo '#!/usr/bin/env python3' > /usr/local/etc/jupyter/startup/99-inject-env.py && \
    cat /usr/local/bin/inject-env.py | tail -n +2 >> /usr/local/etc/jupyter/startup/99-inject-env.py && \
    chmod +x /usr/local/etc/jupyter/startup/99-inject-env.py

# install Amazon cli
RUN curl -fsSL https://awscli.amazonaws.com/v2/install.sh | sudo bash -s -- --system


USER $NB_USER

RUN echo "PROJ_LIB=/opt/conda/share/proj" >> /opt/conda/lib/R/etc/Renviron.site

# Install Conda packages
COPY --chown=$NB_UID:$NB_GID conda-packages.txt /home/jovyan/
RUN set -ex \
  && mamba install --quiet --yes --file conda-packages.txt \
  && mamba clean --all -f -y \
  && conda clean --all --yes && rm -rf /opt/conda/pkgs/*

RUN jupyter lab build -y \
  && jupyter lab clean -y \
  && rm -rf "/home/${NB_USER}/.cache/yarn" \
  && rm -rf "/home/${NB_USER}/.node-gyp" \
  && npm cache clean --force 2>/dev/null || true \
  && fix-permissions "${CONDA_DIR}" \
  && fix-permissions "/home/${NB_USER}"

RUN pip install jupyter-rsession-proxy

# Install Pip packages
COPY --chown=$NB_UID:$NB_GID pip-packages.txt /home/jovyan/
RUN pip install -r pip-packages.txt \
  && jupyter server extension enable nbgitpuller jupyter_git jupyterlab-a11y-checker --sys-prefix \
  && pip cache purge

# Install npm packages
COPY --chown=$NB_UID:$NB_GID npm-packages.txt /home/jovyan/
RUN xargs -a npm-packages.txt -r npm install -g

# Install R packages
COPY --chown=$NB_UID:$NB_GID install.R /home/jovyan/
## Run an install.R script, if it exists.
RUN if [ -f install.R ]; then R --quiet -f install.R; fi

