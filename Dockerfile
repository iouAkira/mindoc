# Ubuntu 20.04
FROM ubuntu:focal

ARG TAG=0.0.1

RUN apt update \
    && apt install -y apt-transport-https ca-certificates curl wget xz-utils \
    && apt install -y --no-install-recommends tzdata \
    # 安装 calibre 依赖的包
    && apt install -y libgl-dev libnss3-dev libxcomposite-dev libxrandr-dev libxi-dev libxdamage-dev \
    # 安装文泉驿字体
    && apt install -y fonts-wqy-microhei fonts-wqy-zenhei \
    # 安装中文语言包
    && apt-get install -y locales language-pack-zh-hans language-pack-zh-hans-base

# 切换默认shell为bash
SHELL ["/bin/bash", "-c"]

# 工作目录
ADD . /go/src/github.com/mindoc-org/mindoc

WORKDIR /install-golang
RUN wget https://go.dev/dl/go1.21.5.linux-amd64.tar.gz -O golang.tar.gz \
    && tar -zxvf golang.tar.gz -C /usr/local/ \
    && echo 'export PATH=$PATH:/usr/local/go/bin' | tee -a /etc/profile \
    && source /etc/profile \
    && go env \
    && cd /go/src/github.com/mindoc-org/mindoc \
    && go mod tidy -v \
    && go build -v -o mindoc_linux_amd64 -ldflags "-w -s -X 'main.VERSION=$TAG' -X 'main.BUILD_TIME=`date`' -X 'main.GO_VERSION=`go version`'" \
    && cp conf/app.conf.example conf/app.conf

RUN mkdir -p /mindoc/__default_assets__ \
    && mv /go/src/github.com/mindoc-org/mindoc/mindoc_linux_amd64 /mindoc/ \
    && mv /go/src/github.com/mindoc-org/mindoc/lib /mindoc/ \
    && mv /go/src/github.com/mindoc-org/mindoc/conf /mindoc/__default_assets__/ \
    && mv /go/src/github.com/mindoc-org/mindoc/static /mindoc/__default_assets__/ \
    && mv /go/src/github.com/mindoc-org/mindoc/views /mindoc/__default_assets__/ \
    && mv /go/src/github.com/mindoc-org/mindoc/uploads /mindoc/__default_assets__/ \
    && rm -rf /install-golang \
    && rm -rf /usr/local/go/ \
    && rm -rf /go/src/github.com/mindoc-org/mindoc/ \
    && apt autoremove -y

WORKDIR /mindoc
# 必要的文件复制
ADD simsun.ttc /usr/share/fonts/win/
ADD start.sh /mindoc

RUN chmod a+r /usr/share/fonts/win/simsun.ttc \
    && chmod +x /mindoc/start.sh

# 时区设置(如果不设置, calibre依赖的tzdata在安装过程中会要求选择时区)
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
# tzdata的前端类型默认为readline（Shell情况下）或dialog（支持GUI的情况下）
ARG DEBIAN_FRONTEND=noninteractive
# 重新配置tzdata软件包，使得时区设置生效
RUN dpkg-reconfigure --frontend noninteractive tzdata

# 设置默认编码
RUN locale-gen "zh_CN.UTF-8" \
    && update-locale LANG=zh_CN.UTF-8

ENV LANG=zh_CN.UTF-8 \
    LANGUAGE=zh_CN:en \
    LC_ALL=zh_CN.UTF-8 \
    ZONEINFO=/mindoc/lib/time/zoneinfo.zip

# 安装-calibre
RUN mkdir -p /tmp/calibre-cache \
    &&  mkdir -p /opt/calibre \
    && wget -O /tmp/calibre-cache/calibre-x86_64.txz -c https://download.calibre-ebook.com/5.44.0/calibre-5.44.0-x86_64.txz \
    && tar xJof /tmp/calibre-cache/calibre-x86_64.txz -C /opt/calibre \
    && rm -rf /tmp/calibre-cache/

# 设置calibre相关环境变量
ENV PATH=$PATH:/opt/calibre \
    QTWEBENGINE_CHROMIUM_FLAGS="--no-sandbox" \
    QT_QPA_PLATFORM='offscreen'
    
VOLUME ["/mindoc/conf","/mindoc/static","/mindoc/views","/mindoc/uploads","/mindoc/runtime","/mindoc/database"]

EXPOSE 8181/tcp

ENTRYPOINT ["/bin/bash", "/mindoc/start.sh"]
