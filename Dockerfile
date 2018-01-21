FROM nvidia/cuda:7.5-cudnn3-devel-ubuntu14.04
MAINTAINER xiongyu <haluoluo@qq.com>

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        cmake \
        git \
        wget \
        zip \
        unzip \
        libatlas-base-dev \
        libboost-all-dev \
        libgflags-dev \
        libgoogle-glog-dev \
        libhdf5-serial-dev \
        libleveldb-dev \
        liblmdb-dev \
        libopencv-dev \
        libprotobuf-dev \
        libsnappy-dev \
        protobuf-compiler \
        python-dev \
        python-numpy \
        python-pip \
        python-setuptools \
        python-scipy \
        python-opencv && \
    rm -rf /var/lib/apt/lists/*

ENV CTPN_ROOT=/opt/ctpn
WORKDIR $CTPN_ROOT

RUN git clone --depth 1 https://github.com/tianzhi0549/CTPN.git
WORKDIR $CTPN_ROOT/CTPN/caffe

# Missing "packaging" package
RUN pip install --upgrade pip
RUN pip install packaging

# -i use tsinghua source for speedup install
RUN cd python && for req in $(cat requirements.txt) pydot; do pip install $req -i https://pypi.tuna.tsinghua.edu.cn/simple/; done && cd ..

WORKDIR $CTPN_ROOT/CTPN/caffe
RUN cp Makefile.config.example Makefile.config
RUN apt-get update && apt-get install -y --no-install-recommends \
    vim
RUN mkdir build && cd build && \
    cmake -DUSE_CUDNN=1 .. && \
    WITH_PYTHON_LAYER=1 make -j"$(nproc)" && make pycaffe

# Set the environment variables so that the paths are correctly configured
ENV PYCAFFE_ROOT $CTPN_ROOT/CTPN/caffe/python
ENV PYTHONPATH $PYCAFFE_ROOT:$PYTHONPATH
ENV PATH $CTPN_ROOT/CTPN/caffe/build/tools:$PYCAFFE_ROOT:$PATH
RUN echo "$CTPN_ROOT/CTPN/caffe/build/lib" >> /etc/ld.so.conf.d/caffe.conf && ldconfig

# To make sure the python layer builds - Need to figure out a cleaner way to do this.
RUN cp $CTPN_ROOT/CTPN/src/layers/* $CTPN_ROOT/CTPN/caffe/src/caffe/layers/
RUN cp $CTPN_ROOT/CTPN/src/*.py $CTPN_ROOT/CTPN/caffe/src/caffe/
RUN cp -r $CTPN_ROOT/CTPN/src/utils $CTPN_ROOT/CTPN/caffe/src/caffe/

WORKDIR $CTPN_ROOT/CTPN
RUN make
