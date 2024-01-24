FROM 763104351884.dkr.ecr.us-east-1.amazonaws.com/pytorch-inference:2.1.0-gpu-py310-cu118-ubuntu20.04-sagemaker

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ARG NB_USER="sagemaker-user"
ARG NB_UID="1000"
ARG NB_GID="100"
ENV NB_USER=$NB_USER \
    NB_UID=$NB_UID \
    NB_GID=$NB_GID \
    HOME=/home/$NB_USER
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
    git && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Create the necessary directory for GPG
RUN mkdir -p /home/sagemaker-user/.gnupg && chown -R $NB_UID:$NB_GID /home/sagemaker-user/.gnupg
RUN echo "deb https://cloud.r-project.org/bin/linux/ubuntu focal-cran40/" >> /etc/apt/sources.list && \
    gpg --keyserver keyserver.ubuntu.com --recv-key 51716619E084DAB9 && \
    gpg -a --export 51716619E084DAB9 | apt-key add - && \
    apt-get update && \
    apt-get install -y r-base

COPY install_r_packages.sh /tmp/install_r_packages.sh
RUN chmod +x /tmp/install_r_packages.sh && /tmp/install_r_packages.sh

ENV PATH=/usr/local/cuda/bin:${PATH} \
    LD_LIBRARY_PATH=/usr/local/cuda/lib64:${LD_LIBRARY_PATH}

WORKDIR /usr/src/python
RUN wget https://www.python.org/ftp/python/3.10.0/Python-3.10.0.tgz && \
    tar xzf Python-3.10.0.tgz && \
    cd Python-3.10.0 && \
    ./configure --enable-shared && \
    make && \
    make install

WORKDIR /
RUN rm -rf /usr/src/python
ENV LD_LIBRARY_PATH /usr/local/lib:$LD_LIBRARY_PATH
RUN update-alternatives --install /usr/bin/python3 python3 /usr/local/bin/python3.10 1

COPY requirements.txt /srv/requirements.txt
RUN apt-get update && apt-get install --yes --no-install-recommends \
    libfreetype6-dev libxft-dev libpng-dev && \
    pip install -r /srv/requirements.txt jupyter && \
    git clone https://github.com/DanGuo1223/DeepMSI.git /home/$NB_USER/DeepMSI && \
    cd /home/$NB_USER/DeepMSI && \
    pip install .

RUN R --quiet -e "IRkernel::installspec(name='ir', user = FALSE)"

RUN useradd --non-unique --create-home --shell /bin/bash --gid "100" --uid 1000 "sagemaker-user"
WORKDIR /home/sagemaker-user
USER 1000