FROM debian:stretch

MAINTAINER Daniel Ibáñez Fernández <daniel.ibanez@softonic.com>


ADD ./docker/jenkins-executor/bin /jenkins-executor

RUN ln -snf /bin/bash /bin/sh

RUN apt-get update \
    && apt-get install -y \
    python \
    python3 \
    python3-pip \
    openssl \
    libssl-dev \
    runit \
    procps \
    wget \
    build-essential \
    libpcre3 \
    libpcre3-dev \
    python3-dateutil \
    socat \
    iptables \
    libreadline-dev \
    jq \
    curl \
    less \
    build-essential \
    && pip3 install -r /jenkins-executor/marathon-lb/requirements.txt

COPY ./bin/config /jenkins-executor/config/

WORKDIR /jenkins-executor

RUN apt-get install -y python-pip \
    && cd dcos-cli \
    && pip install virtualenv \
    && make env \
    && make packages \
    && cd cli \
    && make env


RUN apt-get remove -yf wget libssl-dev build-essential libpcre3-dev libreadline-dev build-essential \
    && apt-get autoremove -yf \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

ENV PATH "/jenkins-executor/dcos-cli/cli/env/bin:$PATH"
ENV MESOS_MASTER_URL "http://master-1.cell-1.dub.softonic.one:5050"
ENV MARATHON_URL "http://master-1.cell-1.dub.softonic.one:8080"

RUN dcos config set core.mesos_master_url $MESOS_MASTER_URL \
    && dcos config set marathon.url $MARATHON_URL

ADD ./docker/jenkins-executor/rootfs /

ENTRYPOINT ["/init"]


