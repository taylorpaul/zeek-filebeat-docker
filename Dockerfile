
# Checkout and build Zeek
FROM debian:bullseye as builder
LABEL original_zeek_author = "Justin Azoff <justin.azoff@gmail.com>"
LABEL author = "Taylor Paul <taylorpaul2011@gmail.com>"

ENV WD /scratch

RUN mkdir ${WD}       
WORKDIR /scratch

RUN apt-get update && apt-get upgrade -y && echo 2021-03-01
RUN apt-get -y install build-essential git bison flex gawk cmake swig libssl-dev libmaxminddb-dev libpcap-dev python3.9-dev libcurl4-openssl-dev wget libncurses5-dev ca-certificates zlib1g-dev --no-install-recommends

ARG ZEEK_VER=4.2.0
ARG BUILD_TYPE=Release
ENV VER ${ZEEK_VER}
ADD ./common/buildbro ${WD}/common/buildbro
RUN ${WD}/common/buildbro zeek ${VER} ${BUILD_TYPE}

# For testing
ADD ./common/getmmdb.sh /usr/local/getmmdb.sh
ADD ./common/bro_profile.sh /usr/local/bro_profile.sh

# Get geoip data
FROM debian:bullseye as geogetter
ARG MAXMIND_LICENSE_KEY
RUN apt-get update && apt-get -y install wget ca-certificates --no-install-recommends

# For testing
COPY --from=builder /usr/local/getmmdb.sh /usr/local/bin/getmmdb.sh
RUN mkdir -p /usr/share/GeoIP
RUN /usr/local/bin/getmmdb.sh ${MAXMIND_LICENSE_KEY}
# This is a workaround for the case where getmmdb.sh does not create any files.
RUN touch /usr/share/GeoIP/.notempty

# Make final image
FROM debian:bullseye
ARG ZEEK_VER=4.2.0
ENV VER ${ZEEK_VER}

# Zeek install section:###########################################

#install runtime dependencies for Zeek (NOTE: Added inotify-tools to look for filesystem changes)
RUN apt-get update \
    && apt-get -y install --no-install-recommends libpcap0.8 libssl1.1 libmaxminddb0 python3.9-minimal inotify-tools\
    && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/zeek-${VER} /usr/local/zeek-${VER}
COPY --from=geogetter /usr/share/GeoIP/* /usr/share/GeoIP/

RUN rm -f /usr/share/GeoIP/.notempty
RUN ln -s /usr/local/zeek-${VER} /bro
RUN ln -s /usr/local/zeek-${VER} /zeek

# For testing
#ADD ./common/bro_profile.sh /etc/profile.d/zeek.sh
COPY --from=builder /usr/local/bro_profile.sh /etc/profile.d/zeek.sh

# Filbeat install section:#########################################
RUN apt-get update && apt-get -y install --no-install-recommends curl dpkg ca-certificates
RUN curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-8.1.3-amd64.deb
RUN sudo dpkg -i filebeat-8.1.3-amd64.deb
RUN filebeat modules enable zeek

# COPY process_pcap.sh for watching for new pcap files:
COPY process_pcap.sh /process_pcap.sh 

ENV PATH=/zeek/bin/:$PATH

# Run the process_pcap when starting 
CMD /bin/bash -l /process_pcap.sh
