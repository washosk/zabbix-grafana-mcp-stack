FROM alpine:3.20

RUN apk add --no-cache postgresql16-client gzip tzdata

COPY backup.sh /usr/local/bin/backup.sh
COPY crontab /etc/crontabs/root

RUN chmod +x /usr/local/bin/backup.sh

# Run one backup immediately on start, then hand off to crond for daily schedule.
# busybox crond (built into Alpine) — does not call setpgid, works without extra capabilities.
CMD ["/bin/sh", "-c", "/usr/local/bin/backup.sh || true; exec crond -f -l 2 -c /etc/crontabs"]
