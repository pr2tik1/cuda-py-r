FROM 763104351884.dkr.ecr.us-east-1.amazonaws.com/pytorch-inference:2.1.0-gpu-py310-cu118-ubuntu20.04-sagemaker

# Set shell to bash with pipefail
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Arguments for user and group
ARG NB_USER="sagemaker-user"
ARG NB_UID="1000"
ARG NB_GID="100"

# Set environment variables
ENV NB_USER=$NB_USER \
    NB_UID=$NB_UID \
    NB_GID=$NB_GID \
    HOME=/home/$NB_USER

# Switch to root user for installation
USER root

RUN set -e && \
    apt-get update && apt-get install --assume-yes --no-install-recommends \
    ca-certificates dirmngr dpkg-dev gcc gnupg libbz2-dev \
    libc6-dev libexpat1-dev libffi-dev liblzma-dev \
    libsqlite3-dev libssl-dev make netbase uuid-dev wget \
    xz-utils zlib1g-dev libfftw3-dev fonts-dejavu \
    unixodbc unixodbc-dev r-cran-rodbc gfortran \
    python3-dev build-essential libxml2-dev libxslt1-dev \
    libpng-dev libcurl4-openssl-dev libtiff-dev \
    libharfbuzz-dev libfribidi-dev axel \
    liblapack-dev libblas-dev libfreetype6-dev libxft-dev libjpeg-dev \
    && \
    apt-get install -y --no-install-recommends \
    r-base \
    git && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Set the environment variable for CUDA
ENV PATH=/usr/local/cuda/bin:${PATH} \
    LD_LIBRARY_PATH=/usr/local/cuda/lib64:${LD_LIBRARY_PATH}

# Install R packages using Bash script
COPY install_r_packages.sh /tmp/install_r_packages.sh
RUN chmod +x /tmp/install_r_packages.sh && /tmp/install_r_packages.sh
RUN R --quiet -e "IRkernel::installspec(name='ir', user = FALSE)"

# Install Python packages and clone DeepMSI repository
COPY requirements.txt /srv/requirements.txt
RUN apt-get update && apt-get install --yes --no-install-recommends \
    libfreetype6-dev libxft-dev libpng-dev && \
    pip install -r /srv/requirements.txt && \
    git clone https://github.com/DanGuo1223/DeepMSI.git /home/$NB_USER/DeepMSI

# Switch back to the non-root user and set the working directory
USER $NB_UID
WORKDIR $HOME