FROM alpine:3.10

WORKDIR /usr/src/app

ENV NGINX_VERSION="1.18.0"
ENV NGINX_OPENTRACING_VERSION="v0.9.0"
ENV NGINX_OPENTRACING_CPP_VERSION="v1.5.1"
ENV ZIPKIN_OPENTRACING_VERSION="v0.5.2"

ENV MAKEFLAGS="-j4"

RUN apk --update add tar build-base gcompat linux-headers pcre-dev zlib-dev gettext openssl-dev git cmake curl curl-dev msgpack-c-dev

RUN mkdir -p /usr/local/nginx/modules && \
    mkdir nginx && wget -q -O - http://nginx.org/download/nginx-1.18.0.tar.gz | tar xz -C nginx --strip-components=1 -f -

RUN cd /usr/src/app && \
    git clone -b $NGINX_OPENTRACING_CPP_VERSION https://github.com/opentracing/opentracing-cpp.git && \
    cd opentracing-cpp && \
    mkdir .build && cd .build && \
    cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF .. && \
    make && make install
RUN cd /usr/src/app && \
    git clone -b $ZIPKIN_OPENTRACING_VERSION https://github.com/rnburn/zipkin-cpp-opentracing.git && \
    cd zipkin-cpp-opentracing && \
    mkdir .build && cd .build && \
    cmake -DBUILD_SHARED_LIBS=1 -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF .. && \
    make && make install
RUN cd /usr/src/app && \
    git clone https://github.com/opentracing-contrib/nginx-opentracing.git
    
COPY --from=0 /usr/local/lib/libopentracing.so.1.5.1 /usr/local/lib/libopentracing.so.1.5.1
COPY --from=0 /usr/local/lib/libzipkin.so.0.5.2 /usr/local/lib/libzipkin.so.0.5.2
COPY --from=0 /usr/local/lib/libzipkin_opentracing.so.0.5.2 /usr/local/lib/libzipkin_opentracing.so.0.5.2
COPY --from=0 /nginx/objs/ngx_http_opentracing_module.so /etc/nginx/modules/ngx_http_opentracing_module.so

RUN \
     ln -s /usr/local/lib/libopentracing.so.1.5.1 /usr/local/lib/libopentracing.so.1  && \
     ln -s /usr/local/lib/libopentracing.so.1 /usr/local/lib/libopentracing.so && \
     ln -s /usr/local/lib/libzipkin.so.0.5.2 /usr/local/lib/libzipkin.so.0 && \
     ln -s /usr/local/lib/libzipkin.so.0 /usr/local/lib/libzipkin.so && \
     ln -s /usr/local/lib/libzipkin_opentracing.so.0.5.2 /usr/local/lib/libzipkin_opentracing.so.0 && \
     ln -s /usr/local/lib/libzipkin_opentracing.so.0 /usr/local/lib/libzipkin_opentracing.so

# https://github.com/opentracing-contrib/nginx-opentracing/issues/72
