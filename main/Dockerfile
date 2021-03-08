ARG version=1.10.5-r1
FROM ghcr.io/exram/freeswitch-base:$version

RUN apk add --update fail2ban
RUN touch /var/log/freeswitch.log \
  && mkdir /var/log/messages   # fail2ban will crash without this directory being present.

ADD ./main/freeswitch.local /etc/fail2ban/jail.d/

CMD fail2ban-server & freeswitch -nonat
