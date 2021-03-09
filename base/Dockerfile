ARG version=1.10.5-r1
ARG versionHeight=1

FROM alpine:3.13 as build
ARG version
ARG versionHeight

RUN apk update \
    && apk add alpine-sdk vim swig \
    && ln `which swig` `which swig`3.0 \
    && mkdir -p /var/cache/distfiles \
    && chmod a+w /var/cache/distfiles \
    && adduser -D freeswitch \
    && addgroup freeswitch abuild

USER freeswitch
WORKDIR /home/freeswitch

RUN abuild-keygen -a -i \
    && git clone https://github.com/ExRam/aports.git \
    && cd aports/main/freeswitch \
    && git checkout freeswitch-v$version-exram \
    && sed -i "s/ExRam Custom Build/ExRam Custom Build $version.$versionHeight/g" exram-start-message.patch \
    && abuild checksum \
    && abuild -r


FROM alpine:3.13 as freeswitch
ARG version

COPY --from=build /home/freeswitch/packages/main/x86_64/* /apks/main/x86_64/

RUN apk add freeswitch=$version freeswitch-sample-config=$version --update-cache --allow-untrusted --repository /apks/main/
