FROM debian:bookworm-slim

RUN    apt-get update \
    && apt-get install -y --no-install-recommends \
       curl build-essential \
       vim less tree ack git \
       carton cpanminus \
       libexpat1-dev \
       libxml2-dev \
       openssl libssl-dev zlib1g-dev \
       pkg-config libyaz-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /home/hks3/HKS3-Koha-Tools

ENV PERL5LIB="${PERL5LIB}:/home/hks3/HKS3-Koha-Tools/lib:/home/hks3/HKS3-Koha-Tools/local/lib/perl5"

RUN echo '#!/bin/sh                                        \n\
                                                           \n\
# Polyfill for building YAZ-based applications on Debian.  \n\
                                                           \n\
if [ $# = 1 -a "x$1" = "x--version" ]; then                \n\
   pkg-config --modversion yaz                             \n\
elif [ $# -ge 1 -a "x$1" = "x--cflags" ]; then             \n\
   pkg-config --cflags yaz-server                          \n\
elif [ $# -ge 1 -a "x$1" = "x--libs" ]; then               \n\
   pkg-config --libs yaz-server                            \n\
else                                                       \n\
   echo "$0 polyfill: unsupported invocation. Try:         \n\
    $0 --version                                           \n\
    $0 --cflags                                            \n\
    $0 --libs                                              \n\
" >&2                                                      \n\
fi                                                         \n\
' >> /usr/bin/yaz-config

RUN chmod ugo+x /usr/bin/yaz-config

CMD ["bash", "./entrypoint.sh"]
