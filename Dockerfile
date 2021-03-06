######################################################### TOOLCHAIN VERSIONING #########################################
#settings values here to be able to use dockerhub autobuild
ARG UBUNTU_VERSION=18.04

ARG DOCKER_VERSION="19.03.13"
ARG KUBECTL_VERSION="1.19.4"
ARG OC_CLI_VERSION="4.6"
ARG HELM_VERSION="2.17.0"
ARG HELM3_VERSION="3.4.1"
ARG TERRAFORM_VERSION="0.12.29"
ARG TERRAFORM13_VERSION="0.13.5"
ARG AWS_CLI_VERSION="1.18.178"
ARG AZ_CLI_VERSION="2.14.2-1~bionic"
ARG GCLOUD_VERSION="318.0.0-0"
ARG KOPS_VERSION="1.18.2"
ARG ANSIBLE_VERSION="2.10.3"
ARG JINJA_VERSION="2.11.2"
ARG OPENSSH_VERSION="8.4p1"
ARG CRICTL_VERSION="1.19.0"

ARG ZSH_VERSION="5.4.2-3ubuntu3.1"
ARG MULTISTAGE_BUILDER_VERSION="2020-06-19"

######################################################### BUILDER ######################################################
FROM ksandermann/multistage-builder:$MULTISTAGE_BUILDER_VERSION as builder
MAINTAINER Kevin Sandermann <kevin.sandermann@gmail.com>
LABEL maintainer="kevin.sandermann@gmail.com"

ARG OC_CLI_VERSION
ARG HELM_VERSION
ARG HELM3_VERSION
ARG TERRAFORM_VERSION
ARG TERRAFORM13_VERSION
ARG DOCKER_VERSION
ARG KUBECTL_VERSION
ARG KOPS_VERSION
ARG CRICTL_VERSION

#download oc-cli
WORKDIR /root/download
RUN mkdir -p oc_cli && \
    curl -SsL --retry 5 -o oc_cli.tar.gz https://mirror.openshift.com/pub/openshift-v4/clients/oc/$OC_CLI_VERSION/linux/oc.tar.gz && \
    tar xzvf oc_cli.tar.gz -C oc_cli

#download helm-cli
RUN mkdir helm2 && curl -SsL --retry 5 "https://get.helm.sh/helm-v$HELM_VERSION-linux-amd64.tar.gz" | tar xz -C ./helm2

#download helm3-cli
RUN mkdir helm3 && curl -SsL --retry 5 "https://get.helm.sh/helm-v$HELM3_VERSION-linux-amd64.tar.gz" | tar xz -C ./helm3

#download terraform
WORKDIR /root/download
RUN wget https://releases.hashicorp.com/terraform/$TERRAFORM_VERSION/terraform\_$TERRAFORM_VERSION\_linux_amd64.zip && \
    unzip ./terraform\_$TERRAFORM_VERSION\_linux_amd64.zip -d terraform_cli

#download terraform
RUN wget https://releases.hashicorp.com/terraform/${TERRAFORM13_VERSION}/terraform\_${TERRAFORM13_VERSION}\_linux_amd64.zip && \
    unzip ./terraform\_${TERRAFORM13_VERSION}\_linux_amd64.zip -d terraform13_cli

#download docker
#credits to https://github.com/docker-library/docker/blob/463595652d2367887b1ffe95ec30caa00179be72/18.09/Dockerfile
RUN mkdir -p /root/download/docker/bin && \
    set -eux; \
    arch="$(uname -m)"; \
    if ! wget -O docker.tgz "https://download.docker.com/linux/static/stable/${arch}/docker-${DOCKER_VERSION}.tgz"; then \
        echo >&2 "error: failed to download 'docker-${DOCKER_VERSION}' from 'stable' for '${arch}'"; \
        exit 1; \
    fi; \
    tar --extract \
        --file docker.tgz \
        --strip-components 1 \
        --directory /root/download/docker/bin

#download kubectl
RUN wget https://storage.googleapis.com/kubernetes-release/release/v$KUBECTL_VERSION/bin/linux/amd64/kubectl -O /root/download/kubectl

#download crictl
RUN mkdir -p /root/download/crictl && \
    wget "https://github.com/kubernetes-sigs/cri-tools/releases/download/v$CRICTL_VERSION/crictl-v$CRICTL_VERSION-linux-amd64.tar.gz" -O /root/download/crictl.tar.gz && \
    tar zxvf /root/download/crictl.tar.gz -C /root/download/crictl  && \
    chmod +x /root/download/crictl/crictl


#download kops
RUN curl -Lo kops https://github.com/kubernetes/kops/releases/download/v$KOPS_VERSION/kops-linux-amd64

#download yq
RUN curl -Lo yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64

######################################################### IMAGE ########################################################

FROM ubuntu:$UBUNTU_VERSION
MAINTAINER Kevin Sandermann <kevin.sandermann@gmail.com>
LABEL maintainer="kevin.sandermann@gmail.com"

# tooling versions
ARG OPENSSH_VERSION
ARG KUBECTL_VERSION
ARG ANSIBLE_VERSION
ARG JINJA_VERSION
ARG AZ_CLI_VERSION
ARG AWS_CLI_VERSION
ARG ZSH_VERSION
ARG GCLOUD_VERSION

#env
ENV EDITOR nano

USER root
WORKDIR /root

#https://github.com/waleedka/modern-deep-learning-docker/issues/4#issue-292539892
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y \
    apt-utils \
    apt-transport-https \
    bash-completion \
    build-essential \
    ca-certificates \
    curl \
    dnsutils \
    fping \
    git \
    gnupg \
    gnupg2 \
    groff \
    iputils-ping \
    jq \
    less \
    libssl-dev \
    locales \
    lsb-release \
    nano \
    net-tools \
    netcat \
    nmap \
    openssl \
    python3 \
    python3-dev \
    python3-pip \
    software-properties-common \
    sudo \
    telnet \
    traceroute \
    unzip \
    uuid-runtime \
    vim \
    wget \
    zip \
    zlib1g-dev &&\
    apt-get clean -y && \
    apt-get autoclean -y && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /var/cache/apt/archives/*

#install zsh
RUN locale-gen en_US.UTF-8
RUN apt-get update && \
    apt-get install -y \
    fonts-powerline \
    powerline \
    zsh=$ZSH_VERSION

ENV TERM xterm
ENV ZSH_THEME agnoster
RUN wget https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh -O - | zsh || true

#keep standard shell for automation usecases
#RUN chsh -s /bin/zsh

#install OpenSSH
RUN wget "https://mirror.exonetric.net/pub/OpenBSD/OpenSSH/portable/openssh-${OPENSSH_VERSION}.tar.gz" --no-check-certificate && \
    tar xfz openssh-${OPENSSH_VERSION}.tar.gz && \
    cd openssh-${OPENSSH_VERSION} && \
    ./configure && \
    make && \
    make install && \
    rm -rf ../openssh-${OPENSSH_VERSION}.tar.gz ../openssh-${OPENSSH_VERSION} && \
    ssh -V

#install ansible + common requirements
RUN pip3 install pip --upgrade
RUN pip3 install cryptography
RUN pip3 install \
    ansible==${ANSIBLE_VERSION} \
    ansible-lint \
    hvac \
    jinja2==${JINJA_VERSION} \
    jmespath \
    netaddr \
    openshift \
    passlib \
    pbr \
    pip \
    pyOpenSSL \
    pyvmomi \
    setuptools

#install AWS CLI
RUN pip3 install awscli==$AWS_CLI_VERSION --upgrade && \
    aws --version


#install azure cli
RUN curl -sL https://packages.microsoft.com/keys/microsoft.asc | \
    gpg --dearmor | \
    tee /etc/apt/trusted.gpg.d/microsoft.asc.gpg > /dev/null && \
    AZ_REPO=$(lsb_release -cs) && \
    echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | \
    tee /etc/apt/sources.list.d/azure-cli.list && \
    apt-get update && \
    apt-get install -y azure-cli=$AZ_CLI_VERSION && \
    az --version && \
    az extension add --name azure-devops

#install gcloud
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add - && \
    apt-get update && \
    apt-get install -y \
    google-cloud-sdk=${GCLOUD_VERSION}

#install binaries
COPY --from=builder "/root/download/helm2/linux-amd64/helm" "/usr/local/bin/helm"
COPY --from=builder "/root/download/helm3/linux-amd64/helm" "/usr/local/bin/helm3"
COPY --from=builder "/root/download/oc_cli/oc" "/usr/local/bin/oc"
COPY --from=builder "/root/download/terraform_cli/terraform" "/usr/local/bin/terraform"
COPY --from=builder "/root/download/terraform13_cli/terraform" "/usr/local/bin/terraform13"
COPY --from=builder "/root/download/docker/bin/*" "/usr/local/bin/"
COPY --from=builder "/root/download/kubectl" "/usr/local/bin/kubectl"
COPY --from=builder "/root/download/crictl/crictl" "/usr/local/bin/crictl"
COPY --from=builder "/root/download/kops" "/usr/local/bin/kops"
COPY --from=builder "/root/download/yq" "/usr/local/bin/yq"

RUN chmod -R +x /usr/local/bin && \
    helm version --client && helm init --client-only && helm repo update && \
    helm3 version && \
    helm3 repo add stable https://charts.helm.sh/stable && \
    helm3 repo update && \
    kubectl version --client=true && \
    crictl --version && \
    oc version --client && \
    terraform version && \
    terraform13 version && \
    docker --version && \
    kops version && \
    yq --version && \
    gcloud version

COPY .bashrc /root/.bashrc
COPY .zshrc /root/.zshrc

WORKDIR /root/project
CMD ["/bin/bash"]
