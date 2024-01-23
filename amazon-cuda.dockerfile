# Stage 1: Build Stage
FROM amazonlinux:latest AS builder
ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG CUDA_VERSION="12.3.2"

# Install build dependencies
RUN yum -y update && \
    yum -y groupinstall "Development Tools" && \
    yum -y install \
        zlib-devel \
        bzip2 \
        bzip2-devel \
        readline \
        readline-devel \
        sqlite \
        sqlite-devel \
        openssl \
        openssl-devel \
        xz \
        xz-devel \
        libffi \
        libffi-devel \
        findutils \
        harfbuzz-devel \
        fribidi-devel \
        libxml2-devel \
        freetype-devel \
        libpng-devel \
        libtiff-devel \
        libjpeg-devel \
        xz-devel \
        fftw-devel \
        git \
        icu \
        libicu-devel \
        libX11-devel && \
    yum clean all && rm -rf /var/cache/yum/*

RUN yum -y install kernel-devel kernel-headers && \
    yum -y install wget && \
    wget https://developer.download.nvidia.com/compute/cuda/${CUDA_VERSION}/local_installers/cuda_${CUDA_VERSION}_545.23.08_linux.run && \
    sh cuda_${CUDA_VERSION}_545.23.08_linux.run --silent --toolkit --override && \
    rm -f cuda_${CUDA_VERSION}_545.23.08_linux.run

# Install Python with shared libraries
ENV PYTHON_VERSION=3.9.7
RUN cd /tmp && \
    wget https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tar.xz && \
    tar xJf Python-${PYTHON_VERSION}.tar.xz && \
    cd Python-${PYTHON_VERSION} && \
    ./configure --enable-shared && \
    make -j$(nproc) && \
    make install && \
    ldconfig && \
    cd / && \
    rm -rf /tmp/Python-${PYTHON_VERSION}*

# Install Python packages
COPY requirements.txt /srv/requirements.txt
RUN pip3 install --no-cache-dir -r /srv/requirements.txt

# Install git, clone DeepMSI repository, and install dependencies
RUN yum -y install git && \
    git clone https://github.com/DanGuo1223/DeepMSI.git /home/sagemaker-user/DeepMSI && \
    cd /home/sagemaker-user/DeepMSI && \
    python3 setup.py install

# Install Jupyter Notebook
RUN yum -y install python3-pip && \
    pip3 install --no-cache-dir jupyter jupyter-client

# Stage 2: Final Stage
FROM amazonlinux:latest
ENV DEBIAN_FRONTEND=noninteractive

# Copy CUDA Toolkit from the builder stage
COPY --from=builder /usr/local/cuda /usr/local/cuda

# Copy Python and necessary files from the builder stage
COPY --from=builder /usr/local/bin/python3 /usr/local/bin/python3
COPY --from=builder /usr/local/lib /usr/local/lib
COPY --from=builder /home/sagemaker-user /home/sagemaker-user

# Set user as the owner of /usr/local/lib/R/site-library
RUN mkdir -p /usr/local/lib/R/site-library && chown -R 1000:100 /usr/local/lib/R/site-library/

# Install R and necessary packages
RUN yum -y update && \
    yum -y install \
        gcc \
        gcc-c++ \
        gfortran \
        wget \
        pcre2-devel \
        libcurl-devel \
        tar \
        gzip \
        readline-devel \
        icu \
        libicu-devel \
        libX11-devel \
        libXt-devel \
        zlib-devel \
        bzip2-devel \
        xz-devel

RUN yum -y install epel-release && \
    yum -y install libcurl-devel

# Download and install R from source
RUN wget https://cran.r-project.org/src/base/R-4/R-4.1.2.tar.gz && \
    tar -xf R-4.1.2.tar.gz && \
    cd R-4.1.2 && \
    ./configure --enable-R-shlib && \
    make && \
    make install && \
    cd / && \
    rm -rf R-4.1.2 R-4.1.2.tar.gz && \
    yum clean all && rm -rf /var/cache/yum/*

# Install R packages using Bash script
COPY install_r_packages.sh /tmp/install_r_packages.sh
RUN chmod +x /tmp/install_r_packages.sh && /tmp/install_r_packages.sh && \
    R --quiet -e "IRkernel::installspec(name='ir', user = FALSE)"

# Create user and set working directory
RUN useradd --non-unique --create-home --shell /bin/bash --gid "100" --uid 1000 "sagemaker-user"
WORKDIR /home/sagemaker-user
USER 1000
