ARG version
FROM ghcr.io/exram/freeswitch-base:$version

WORKDIR /home

COPY ./main/entrypoint.sh ./
RUN chmod +x ./entrypoint.sh

CMD ./entrypoint.sh

