FROM debian:bookworm-slim

RUN    apt-get update \
    && apt-get install -y --no-install-recommends \
       curl build-essential \
       vim less tree ack git \
       carton cpanminus \
       libexpat1-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /home/hks3/HKS3-Koha-Tools

ENV PERL5LIB="${PERL5LIB}:/home/hks3/HKS3-Koha-Tools/lib:/home/hks3/HKS3-Koha-Tools/local/lib/perl5"

CMD ["bash", "./entrypoint.sh"]
