FROM busybox as app

WORKDIR /app
COPY . .

ENTRYPOINT ["/app/docker-entrypoint.sh"]

CMD ["ping", "google.com"]
