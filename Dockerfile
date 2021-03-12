# FROM philosowaffle/opentracing-cpp-arm as opentracing
FROM linuxserver/swag:latest AS buildstage

ENV NGINX_VERSION 1.18.0
ENV OPENTRACING_CPP_VERSION 1.6.0
ENV NGINX_OPENTRACING_VERSION 0.13.0
ENV JAGER_TRACING 0.7.0

# COPY --from=opentracing / /
RUN apk add --no-cache --virtual .build-deps \
  gcc \
  libc-dev \
  make \
  openssl-dev \
  pcre-dev \
  zlib-dev \
  linux-headers \
  gnupg \
  libxslt-dev \
  gd-dev \
  geoip-dev \
  g++ \
  cmake \
  apache2-utils \
  libressl3.1-libssl

RUN wget "https://github.com/opentracing/opentracing-cpp/archive/v${OPENTRACING_CPP_VERSION}.tar.gz" -O opentracing-cpp.tar.gz && \
  mkdir -p opentracing-cpp/.build && \
  tar zxvf opentracing-cpp.tar.gz -C ./opentracing-cpp/ --strip-components=1 && \
  cd opentracing-cpp/.build && \
  cmake .. && \
  make && \
  make install

RUN cd /etc && git clone --depth 1 --branch v${NGINX_OPENTRACING_VERSION} https://github.com/opentracing-contrib/nginx-opentracing.git

RUN wget "http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz" -O nginx.tar.gz
RUN CONFGARGS=CONFARGS=$(nginx -V 2>&1 | sed -n -e 's/^.*arguments: //p') \
    CONFARGS=${CONFARGS/-Os -fomit-frame-pointer/-Os}
RUN echo $CONFARGS
RUN mkdir /usr/src && \
	tar -zxC /usr/src -f nginx.tar.gz && \
  OPENTRACING="/etc/nginx-opentracing/opentracing" && \
  cd /usr/src/nginx-$NGINX_VERSION && \
  ./configure --with-compat $CONFARGS --add-dynamic-module=$OPENTRACING && \
  make && make install

RUN ls -l /usr/src/nginx-$NGINX_VERSION

# FROM philosowaffle/jaeger-client-arm as jaeger
FROM scratch as bundle

# COPY --from=jaeger /libjaegertracing/ /root-layer/custom_modules/
# COPY --from=jaeger /libjaegertracing/ /root-layer/var/lib/nginx/

COPY --from=buildstage /usr/local/lib/ /root-layer/custom_modules/
COPY --from=buildstage /usr/local/lib/libopentracing* /root-layer/usr/lib

COPY --from=buildstage /usr/local/nginx/modules/ngx_http_opentracing_module.so /root-layer/custom_modules/ngx_http_opentracing_module.so
COPY --from=buildstage /usr/local/nginx/modules/ngx_http_opentracing_module.so /root-layer/var/lib/nginx/modules/ngx_http_opentracing_module.so

COPY root/ /root-layer/

FROM scratch
COPY --from=bundle /root-layer/ /

# https://github.com/opentracing-contrib/nginx-opentracing/issues/72
# https://gist.github.com/hermanbanken/96f0ff298c162a522ddbba44cad31081
# https://sund5429.medium.com/add-jaeger-tracing-to-nginx-7de1d731ee6e
