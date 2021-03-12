FROM scratch
COPY root/ /

# https://github.com/opentracing-contrib/nginx-opentracing/issues/72
# https://gist.github.com/hermanbanken/96f0ff298c162a522ddbba44cad31081
# https://sund5429.medium.com/add-jaeger-tracing-to-nginx-7de1d731ee6e
