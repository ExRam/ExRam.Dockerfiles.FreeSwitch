ARG version=1.10.5-r1
FROM ghcr.io/exram/freeswitch-base:$version

### fail2ban
RUN apk add --update fail2ban
RUN touch /var/log/freeswitch.log # fail2ban will crash without this file being present.
RUN mkdir /var/log/messages       # fail2ban will crash without this directory being present.

COPY ./main/files/ /

WORKDIR /home
COPY ./main/entrypoint.sh ./
RUN chmod +x ./entrypoint.sh
CMD ./entrypoint.sh

