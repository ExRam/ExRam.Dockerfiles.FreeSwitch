ARG alpineVersion=3.19

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

WORKDIR /home/freeswitch
COPY --chown=freeswitch aports/. aports/.

WORKDIR aports/main/freeswitch
COPY ./exram-start-message.patch .

RUN sed -i "/^source=/ s/$/\texram-start-message.patch/" APKBUILD && \
    sed -i "s/ExRam Custom Build/ExRam Custom Build $version.$versionHeight on Alpine $alpineVersion/g" exram-start-message.patch && \
    sed -i "s/#event_handlers\/mod_fail2ban/event_handlers\/mod_fail2ban/" modules.conf && \
    sed -i "s/#asr_tts\/mod_unimrcp/asr_tts\/mod_unimrcp/" modules.conf && \
    abuild checksum && \
    abuild -r


FROM alpine:$alpineVersion as freeswitch
ARG version

COPY --from=build /home/freeswitch/packages/main/ /apks/main/
RUN apk add freeswitch=$version freeswitch-sample-config=$version --update-cache --allow-untrusted --repository /apks/main/

### fail2ban
RUN apk add --update fail2ban
RUN touch /var/log/freeswitch/freeswitch.log  # fail2ban will crash without this file being present.
RUN mkdir /var/log/messages                   # fail2ban will crash without this directory being present


WORKDIR /home
COPY ./entrypoint.sh ./
RUN chmod +x ./entrypoint.sh

CMD ./entrypoint.sh
