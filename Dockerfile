ARG BUILD_FROM
FROM $BUILD_FROM

COPY rootfs /

COPY requirements.txt /tmp/

RUN \
  pip3 install -r /tmp/requirements.txt && \
  apk add --no-cache inotify-tools nodejs npm && \
  npm install -g prettier
