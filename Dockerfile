FROM nginx:1.13.9
LABEL maintainer="Jason Wilder mail@jasonwilder.com"

# Install wget and install/updates certificates
RUN apt-get update \
 && apt-get install -y -q --no-install-recommends \
    ca-certificates \
    wget \
    nginx-extras \
    gcc \
    g++ \
    unzip \
    make \
 && apt-get clean \
 && rm -r /var/lib/apt/lists/*

# Nginx recompilation dependencies
RUN wget ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre-8.41.tar.gz \
  && tar -zxf pcre-8.41.tar.gz
RUN wget http://zlib.net/zlib-1.2.11.tar.gz \
  && tar -zxf zlib-1.2.11.tar.gz

RUN wget http://nginx.org/download/nginx-1.13.9.tar.gz \
  && tar -xzvf nginx-1.13.9.tar.gz

RUN wget https://github.com/AirisX/nginx_cookie_flag_module/archive/master.zip \
  && unzip master.zip
WORKDIR "/nginx-1.13.9"
RUN ./configure --with-pcre=../pcre-8.41 --with-zlib=../zlib-1.2.11 --with-compat --add-dynamic-module=../nginx_cookie_flag_module-master
RUN make modules
RUN cp /nginx-1.13.9/objs/ngx_http_cookie_flag_filter_module.so /usr/lib/nginx/modules/
WORKDIR "/"

RUN echo "load_module modules/ngx_http_cookie_flag_filter_module.so;" \
  > /etc/nginx/modules-enabled/50-mod-http-cookie_flag_filter.conf

# Configure Nginx and apply fix for very long server names
RUN echo "daemon off;" >> /etc/nginx/nginx.conf \
 && sed -i 's/worker_processes  1/worker_processes  auto/' /etc/nginx/nginx.conf

# Install Forego
ADD https://github.com/jwilder/forego/releases/download/v0.16.1/forego /usr/local/bin/forego
RUN chmod u+x /usr/local/bin/forego

ENV DOCKER_GEN_VERSION 0.7.3

RUN wget https://github.com/jwilder/docker-gen/releases/download/$DOCKER_GEN_VERSION/docker-gen-linux-amd64-$DOCKER_GEN_VERSION.tar.gz \
 && tar -C /usr/local/bin -xvzf docker-gen-linux-amd64-$DOCKER_GEN_VERSION.tar.gz \
 && rm /docker-gen-linux-amd64-$DOCKER_GEN_VERSION.tar.gz

# cleanup
RUN apt-get remove -y --purge \
  gcc \
  g++ \
  unzip \
  make
RUN rm -rf nginx-1.13.9 \
  nginx-1.13.9.tar.gz \
  pcre-8.41 \
  pcre-8.41.tar.gz \
  zlib-1.2.11 \
  zlib-1.2.11.tar.gz \
  nginx_cookie_flag_module-master \
  master.zip \


COPY network_internal.conf /etc/nginx/

COPY . /app/
WORKDIR /app/

ENV DOCKER_HOST unix:///tmp/docker.sock

VOLUME ["/etc/nginx/certs", "/etc/nginx/dhparam"]

ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["forego", "start", "-r"]
