ARG alpineVersion=

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
RUN abuild-keygen -a -i -n

WORKDIR /home/freeswitch/apkbuild
COPY --chown=freeswitch ./aports/main/freeswitch .

COPY ./json-console.patch .
COPY ./add-traceparent-to-logs.patch .
COPY ./exram-start-message.patch .

RUN sed -i "/^source=/ s/$/\tjson-console.patch/" APKBUILD && \
    sed -i "/^source=/ s/$/\tadd-traceparent-to-logs.patch/" APKBUILD && \
    sed -i "/^source=/ s/$/\texram-start-message.patch/" APKBUILD && \
    sed -i "s/ExRam Custom Build/ExRam Custom Build $version.$versionHeight on Alpine $alpineVersion/g" exram-start-message.patch && \
    sed -i "s/#event_handlers\/mod_fail2ban/event_handlers\/mod_fail2ban/" modules.conf && \
    abuild checksum && \
    abuild -r

FROM alpine:$alpineVersion as freeswitch
ARG version

COPY --from=build /home/freeswitch/packages/freeswitch /apks/
RUN apk add freeswitch=$version freeswitch-sample-config=$version --update-cache --allow-untrusted --repository /apks/
RUN rm -R /apks

### fail2ban
RUN apk add --update fail2ban
RUN touch /var/log/freeswitch/freeswitch.log  # fail2ban will crash without this file being present.
RUN mkdir /var/log/messages                   # fail2ban will crash without this directory being present


WORKDIR /home
COPY ./entrypoint.sh ./
RUN chmod +x ./entrypoint.sh

CMD ./entrypoint.sh
