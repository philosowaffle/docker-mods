ARG CACHEBUST=1 

FROM alpine:3.10 as buildstage1

RUN \
     apk update && \
     apk upgrade && \
     apk add curl && \
     apk add curl-dev protobuf-dev pcre-dev openssl-dev && \
     apk add build-base cmake autoconf automake git && \
     echo $CACHEBUST
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

RUN  git clone -b release-1.18.0 https://github.com/nginx/nginx.git
RUN \
     cd nginx && \
     auto/configure \
        --with-compat \
        --add-dynamic-module=/nginx-opentracing/opentracing \
        --with-debug && \
     make modules && \
     ls -l objs && \
     echo Made
RUN  ls -l /usr/local/lib
RUN  ls -l /nginx/objs

FROM scratch

COPY --from=buildstage1 /usr/local/lib/libopentracing.so.1.5.1 root/custom_modules/libopentracing.so
COPY --from=buildstage1 /usr/local/lib/libzipkin.so.0.5.2 root/custom_modules/libzipkin.so
COPY --from=buildstage1 /usr/local/lib/libzipkin_opentracing.so.0.5.2 root/custom_modules/libzipkin_opentracing_plugin.so
COPY --from=buildstage1 /nginx/objs/ngx_http_opentracing_module.so root/custom_modules/ngx_http_opentracing_module.so
COPY root/ /

# https://github.com/opentracing-contrib/nginx-opentracing/issues/72
