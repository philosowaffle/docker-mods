ARG CACHEBUST=1 

FROM nginx:1.18.0-alpine as buildstage

RUN \
     apk update && \
     apk upgrade && \
     apk add curl && \
     apk add curl-dev protobuf-dev pcre-dev openssl-dev && \
     apk add build-base cmake autoconf automake git && \
     apk add gcompat libgcc libstdc++ pcre
RUN  git clone -b v1.5.1 https://github.com/opentracing/opentracing-cpp.git
RUN  cd opentracing-cpp && \
     mkdir .build && cd .build && ls && \
     cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF .. && ls && \
     make && make install
RUN  git clone -b v0.5.2 https://github.com/rnburn/zipkin-cpp-opentracing.git
RUN  cd zipkin-cpp-opentracing && \
     mkdir .build && cd .build && \
     cmake -DBUILD_SHARED_LIBS=1 -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF .. && \
     make && make install
RUN  git clone https://github.com/opentracing-contrib/nginx-opentracing.git
RUN  ls -l /nginx-opentracing/opentracing

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
  geoip-dev

RUN curl "http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz" -o nginx.tar.gz
RUN CONFARGS=$(nginx -V 2>&1 | sed -n -e 's/^.*arguments: //p') \
    CONFARGS=${CONFARGS/-Os -fomit-frame-pointer/-Os} && \
    mkdir /usr/src && \
	tar -zxC /usr/src -f nginx.tar.gz && \
  cd /usr/src/nginx-$NGINX_VERSION && \
  ./configure --with-compat $CONFARGS --add-dynamic-module=/nginx-opentracing/opentracing && \
  make modules && \
  mv ./objs/*.so /nginxObjs

RUN  ls -l /usr/local/lib
RUN  ls -l /usr/src/nginx-1.18.0/objs
RUN ls -l /nginxObjs

FROM scratch as bundle

COPY --from=buildstage /usr/local/lib/libopentracing.so.1.5.1 /root-layer/custom_modules/libopentracing.so
COPY --from=buildstage /usr/local/lib/libzipkin.so.0.5.2 /root-layer/custom_modules/libzipkin.so
COPY --from=buildstage /usr/local/lib/libzipkin_opentracing.so.0.5.2 r/oot-layer/custom_modules/libzipkin_opentracing_plugin.so
COPY --from=buildstage /nginxObjs/ngx_http_opentracing_module.so /root-layer/custom_modules/ngx_http_opentracing_module.so
COPY root/ /root-layer/

FROM scratch
COPY --from=bundle /root-layer/ /

# https://github.com/opentracing-contrib/nginx-opentracing/issues/72
# https://gist.github.com/hermanbanken/96f0ff298c162a522ddbba44cad31081
