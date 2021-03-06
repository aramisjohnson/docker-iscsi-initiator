FROM ubuntu:16.04
MAINTAINER aramisjohnson <aramis.johnson2010@gmail.com>

RUN apt-get update
RUN apt-get -y install open-iscsi

RUN mkdir -p /mnt/storage
WORKDIR /tmp
COPY ./mount-iscsi.sh ./
RUN chmod +x ./mount-iscsi.sh

ENV IP 192.168.0.1
ENV PORT 3260
ENV TARGETNAME iqn.2005-10.org.freenas.ctl:mystorage
ENV LUN 0
ENV DATA anything

ENTRYPOINT ["/bin/bash","/tmp/mount-iscsi.sh"]
