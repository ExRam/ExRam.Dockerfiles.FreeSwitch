FROM ghcr.io/exram/freeswitch-base:1.10.5-r1

RUN apk add --update fail2ban
RUN mkdir /var/log/messages   # fail2ban will crash without this directory being present.

CMD fail2ban-server & freeswitch -nonat
