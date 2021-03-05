FROM alpine:3.13 as build

RUN apk update \
    && apk add alpine-sdk vim swig \
    && ln `which swig` `which swig`3.0 \
    && mkdir -p /var/cache/distfiles \
    && chmod a+w /var/cache/distfiles \
    && adduser -D freeswitch \
    && addgroup freeswitch abuild

USER freeswitch
WORKDIR /home/freeswitch

RUN    abuild-keygen -a -i \
    && git clone https://github.com/ExRam/aports.git \
    && cd aports/main/freeswitch \
    && abuild checksum \
    && abuild -r

FROM alpine:3.13 as freeswitch
COPY --from=build /home/freeswitch/packages/main/x86_64/* /apks/main/x86_64/
RUN apk add freeswitch=1.10.5-r2 --update-cache --allow-untrusted --repository /apks/main/
RUN apk add --update bash curl wget iproute2 
CMD ["freeswitch", "-nonat"]
