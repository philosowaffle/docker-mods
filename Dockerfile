FROM scratch

COPY --from=philosowaffle/nginx-opentracing-arm:latest /modules/ngx_http_opentracing_module.so /usr/lib/nginx/modules/ngx_http_opentracing_module.so
COPY --from=philosowaffle/nginx-opentracing-arm:latest /usr/local/lib/libzipkin_opentracing.so /usr/lib/nginx/modules/libzipkin_opentracing_plugin..so
COPY --from=philosowaffle/nginx-opentracing-arm:latest /usr/local/lib/libjaegertracing.so /usr/lib/nginx/modules/libjaegertracing_plugin.so
COPY --from=philosowaffle/nginx-opentracing-arm:latest /usr/local/lib/libdd_opentracing.so /usr/lib/nginx/modules/libdd_opentracing_plugin.so

# copy local files
# COPY root/ /
