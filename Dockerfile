ARG alpineVersion=3.15

FROM alpine:$alpineVersion as build
ARG version
ARG versionHeight
ARG alpineVersion

RUN apk update \
    && apk add alpine-sdk sudo \
    && mkdir -p /var/cache/distfiles \
    && chmod a+w /var/cache/distfiles \
    && adduser -D freeswitch \
    && addgroup freeswitch abuild \
    && echo "freeswitch ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER freeswitch
WORKDIR /home/freeswitch

RUN abuild-keygen -a -i -n \
    && git clone https://github.com/ExRam/aports.git \
    && cd aports/main/freeswitch \
    && git checkout fcd91539c8675d64d9d7ace6b93bb6370748e7a4 \
    && sed -i "s/ExRam Custom Build/ExRam Custom Build $version.$versionHeight on Alpine $alpineVersion/g" exram-start-message.patch \
    && abuild checksum \
    && abuild -r


FROM alpine:$alpineVersion as freeswitch
ARG version

COPY --from=build /home/freeswitch/packages/main/x86_64/* /apks/main/x86_64/
RUN apk add freeswitch=$version freeswitch-sample-config=$version --update-cache --allow-untrusted --repository /apks/main/

WORKDIR /home
COPY ./entrypoint.sh ./
RUN chmod +x ./entrypoint.sh

CMD ./entrypoint.sh

