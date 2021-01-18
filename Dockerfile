FROM alpine:3.12.0 AS build

ARG VERSION=0.80.0
ADD https://github.com/gohugoio/hugo/releases/download/v${VERSION}/hugo_${VERSION}_Linux-64bit.tar.gz /hugo.tar.gz

RUN tar -zxvf hugo.tar.gz \
  && mv /hugo /usr/bin/hugo \
  && hugo version \
  && apk add --no-cache git 

COPY . /app

WORKDIR /app

RUN hugo --minify --enableGitInfo 

FROM nginx:1.19-alpine

WORKDIR /usr/share/nginx/html/

COPY --from=build /app/public /usr/share/nginx/html

EXPOSE 80