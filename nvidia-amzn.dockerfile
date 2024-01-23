# Stage 1: Build Stage
FROM nvidia/cuda:9.0-cudnn7-devel-ubuntu16.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive
ENV LD_LIBRARY_PATH $LD_LIBRARY_PATH:/usr/local/cuda/extras/CUPTI/lib64:/usr/local/cuda/lib64:/usr/lib/x86_64-linux-gnu/:/usr/local/cuda/lib64/stubs/

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential curl wget git python3 python3-dev python3-pip python3-wheel python3-numpy \
    libcurl3-dev ca-certificates gcc sox libsox-fmt-mp3 htop nano swig cmake \
    libboost-all-dev zlib1g-dev libbz2-dev liblzma-dev locales pkg-config libsox-dev sudo \
    tzdata software-properties-common gdebi-core pandoc pandoc-citeproc \
    libcairo2-dev libxt-dev net-tools \
    libnccl2=2.2.13-1+cuda9.0 libnccl-dev=2.2.13-1+cuda9.0 cuda-command-line-tools-9-0

RUN wget https://bootstrap.pypa.io/get-pip.py && python get-pip.py && rm get-pip.py

ENV TF_NEED_CUDA 1
ENV CUDA_TOOLKIT_PATH /usr/local/cuda
ENV CUDA_PKG_VERSION 9-0=9.0.176-1
ENV CUDA_VERSION 9.0.176
ENV TF_CUDA_VERSION 9.0
ENV TF_CUDNN_VERSION 7.3.0
ENV CUDNN_INSTALL_PATH /usr/lib/x86_64-linux-gnu/
ENV TF_CUDA_COMPUTE_CAPABILITIES 6.0
ENV TF_NCCL_VERSION 2.2.13

RUN mkdir -p /usr/local/cuda/lib && ln -s /usr/lib/x86_64-linux-gnu/libnccl.so.2 /usr/local/cuda/lib/libnccl.so.2 && \
    ln -s /usr/include/nccl.h /usr/local/cuda/include/nccl.h && \
    ln -s /usr/local/cuda/lib64/stubs/libcuda.so /usr/local/cuda/lib64/stubs/libcuda.so.1 && \
    ln -s /usr/include/cudnn.h /usr/local/cuda/include/cudnn.h

RUN apt-get install -y --no-install-recommends r-base r-base-dev libssl-dev libcurl4-openssl-dev

ENV PYTHON_VERSION=3.9.7
RUN wget https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tar.xz && \
    tar xJf Python-${PYTHON_VERSION}.tar.xz && cd Python-${PYTHON_VERSION} && \
    ./configure --enable-shared && make -j$(nproc) && make install && ldconfig && cd / && rm -rf Python-${PYTHON_VERSION}*

COPY requirements.txt /srv/requirements.txt
RUN pip3 install --no-cache-dir -r /srv/requirements.txt

RUN apt-get install -y --no-install-recommends git
RUN git clone https://github.com/DanGuo1223/DeepMSI.git /home/sagemaker-user/DeepMSI && \
    cd /home/sagemaker-user/DeepMSI && python3 setup.py install

RUN apt-get install -y --no-install-recommends python3-pip
RUN pip3 install --no-cache-dir jupyter jupyter-client

RUN mkdir -p /usr/local/lib/R/site-library && chown -R 1000:100 /usr/local/lib/R/site-library/

COPY install_r_packages.sh /tmp/install_r_packages.sh
RUN chmod +x /tmp/install_r_packages.sh && /tmp/install_r_packages.sh && \
    R --quiet -e "IRkernel::installspec(name='ir', user = FALSE)"

# Stage 2: Final Stage
FROM nvidia/cuda:9.0-cudnn7-devel-ubuntu16.04

COPY --from=builder /usr/local/cuda /usr/local/cuda
COPY --from=builder /usr/local/bin/python3 /usr/local/bin/python3
COPY --from=builder /usr/local/lib /usr/local/lib
COPY --from=builder /home/sagemaker-user /home/sagemaker-user

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc gfortran wget pcre2-dev libcurl4-openssl-dev tar gzip readline-dev \
    icu libicu-dev libx11-dev libxt-dev zlib1g-dev bzip2 xz-utils curl

RUN apt-get install -y --no-install-recommends \
    r-base r-base-dev libssl-dev libcurl4-openssl-dev

COPY install_r_packages.sh /tmp/install_r_packages.sh
RUN chmod +x /tmp/install_r_packages.sh && /tmp/install_r_packages.sh && \
    R --quiet -e "IRkernel::installspec(name='ir', user = FALSE)"

RUN useradd --non-unique --create-home --shell /bin/bash --gid "100" --uid 1000 "sagemaker-user"
WORKDIR /home/sagemaker-user
USER 1000
