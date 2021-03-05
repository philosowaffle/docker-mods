ARG CACHEBUST=1 

FROM opentracing-contrib/nginx-opentracing:latest as buildstage

FROM scratch as bundle

COPY --from=buildstage /usr/local/lib/libzipkin_opentracing.so /root-layer/custom_modules/libzipkin_opentracing_plugin.so
COPY --from=buildstage /usr/local/lib/libjaegertracing.so /root-layer/custom_modules/libjaegertracing_plugin.so
COPY --from=buildstage /objs/ngx_http_opentracing_module.so /root-layer/custom_modules/ngx_http_opentracing_module.so
COPY root/ /root-layer/

FROM scratch
COPY --from=bundle /root-layer/ /

# https://github.com/opentracing-contrib/nginx-opentracing/issues/72

# /usr/local/lib/libzipkin_opentracing.so /usr/local/lib/libzipkin_opentracing_plugin.so
# objs/ngx_http_opentracing_module.so
# https://github.com/opentracing-contrib/nginx-opentracing/blob/master/Dockerfile
