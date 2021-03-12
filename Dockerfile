FROM ghcr.io/linuxserver/baseimage-alpine:3.13 AS buildstage

ENV NGINX_VERSION 1.18.0
ENV OPENTRACING_CPP_VERSION 1.6.0
ENV NGINX_OPENTRACING_VERSION 0.13.0
ENV JAGER_TRACING 0.7.0

# Download sources
RUN wget "http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz" -O nginx.tar.gz 

# For latest build deps, see https://github.com/nginxinc/docker-nginx/blob/master/mainline/alpine/Dockerfile
RUN apk add --no-cache --virtual .build-deps \
  gcc \
  libc-dev \
  make \
  openssl-dev \
  pcre-dev \
  zlib-dev \
  linux-headers \
  curl \
  gnupg \
  libxslt-dev \
  gd-dev \
  geoip-dev \
  g++ \
  git \
  cmake \
  apache2-utils \
  git \
  libressl3.1-libssl \
  logrotate \
  nano \
  nginx
  
RUN wget "https://github.com/jaegertracing/jaeger-client-cpp/archive/v${JAGER_TRACING}.tar.gz" -O jaeger-tracing.tar.gz && \
  mkdir -p jaeger-tracing && \
  tar zxvf jaeger-tracing.tar.gz -C ./jaeger-tracing/ --strip-components=1 && \
  cd jaeger-tracing \
  && mkdir .build && cd .build \
  && cmake -DCMAKE_BUILD_TYPE=Release \
           -DBUILD_TESTING=OFF \
           -DJAEGERTRACING_WITH_YAML_CPP=ON .. \
  && make && make install \
  && export HUNTER_INSTALL_DIR=$(cat _3rdParty/Hunter/install-root-dir) \
  && cp /usr/local/lib64/libjaegertracing.so /usr/local/lib/libjaegertracing_plugin.so 
  
RUN wget "https://github.com/opentracing/opentracing-cpp/archive/v${OPENTRACING_CPP_VERSION}.tar.gz" -O opentracing-cpp.tar.gz && \
  mkdir -p opentracing-cpp/.build && \
  tar zxvf opentracing-cpp.tar.gz -C ./opentracing-cpp/ --strip-components=1 && \
  cd opentracing-cpp/.build && \
  cmake .. && \
  make && \
  make install
RUN cd /etc && git clone --depth 1 --branch v${NGINX_OPENTRACING_VERSION} https://github.com/opentracing-contrib/nginx-opentracing.git
# Reuse same cli arguments as the nginx:alpine image used to build

RUN CONFARGS=$(nginx -V 2>&1 | sed -n -e 's/^.*arguments: //p') \
    CONFARGS=${CONFARGS/-Os -fomit-frame-pointer/-Os} && \
    mkdir /usr/src && \
	tar -zxC /usr/src -f nginx.tar.gz && \
  OPENTRACING="/etc/nginx-opentracing/opentracing" && \
  cd /usr/src/nginx-$NGINX_VERSION && \
  ./configure --with-compat $CONFARGS --add-dynamic-module=$OPENTRACING && \
  make && make install
  
FROM scratch as bundle

COPY --from=buildstage /usr/local/lib/ /root-layer/custom_modules/
COPY --from=buildstage /usr/local/lib/ /root-layer/var/lib/nginx/
COPY --from=buildstage /usr/lib/nginx/modules/ngx_http_opentracing_module.so /root-layer/custom_modules/ngx_http_opentracing_module.so
COPY --from=buildstage /usr/lib/nginx/modules/ngx_http_opentracing_module.so /root-layer/var/lib/nginx/modules/ngx_http_opentracing_module.so
COPY root/ /root-layer/

FROM scratch
COPY --from=bundle /root-layer/ /

# https://github.com/opentracing-contrib/nginx-opentracing/issues/72
# https://gist.github.com/hermanbanken/96f0ff298c162a522ddbba44cad31081
# https://sund5429.medium.com/add-jaeger-tracing-to-nginx-7de1d731ee6e
