FROM registry.bft.local/tech/templates/base-images/tarantool:0.0.24

ENV TARANTOOL_APP_NAME=tarantool-api
ENV TARANTOOL_WORKDIR=/var/lib/tarantool/$TARANTOOL_APP_NAME

WORKDIR /usr/share/tarantool/$TARANTOOL_APP_NAME

ADD --chown=tarantool:tarantool *.tar.gz ./

USER tarantool

ENTRYPOINT ["tarantool","init.lua"]
