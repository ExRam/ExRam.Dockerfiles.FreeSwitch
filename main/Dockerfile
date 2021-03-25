ARG version=1.10.5-r1
FROM ghcr.io/exram/freeswitch-base:$version


WORKDIR /home
COPY ./main/entrypoint.sh ./
RUN chmod +x ./entrypoint.sh
CMD ./entrypoint.sh

