FROM alpine:3.19

RUN apk add --no-cache nginx nginx-mod-rtmp ffmpeg

COPY nginx.conf /etc/nginx/nginx.conf
COPY public /usr/share/nginx/html

EXPOSE 80 1935

CMD ["nginx", "-g", "daemon off;"]
