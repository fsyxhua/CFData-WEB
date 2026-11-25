# 在独立 Go 模块中构建，静态页面和 CA 证书由 Go 嵌入二进制。
ARG GO_VERSION=1.26
FROM golang:${GO_VERSION}-alpine AS build

WORKDIR /src
COPY combined_refactor/go.mod combined_refactor/go.sum ./
RUN go mod download
COPY combined_refactor/ ./

ARG VERSION=dev
RUN go test ./... \
    && go vet ./... \
    && CGO_ENABLED=0 go build -trimpath \
       -ldflags="-s -w -X main.appVersion=${VERSION}" -o /out/cfdata .

FROM alpine:3.23 AS runtime

RUN apk add --no-cache ca-certificates tzdata \
    && addgroup -S -g 10001 cfdata \
    && adduser -S -D -H -u 10001 -G cfdata cfdata \
    && mkdir -p /data \
    && chown cfdata:cfdata /data \
    # 配置默认写在可执行文件旁，将其链接到持久化目录。
    && ln -s /data/cfdata-config.json /usr/local/bin/cfdata-config.json \
    && ln -s /data/cfdata-config.json.bak /usr/local/bin/cfdata-config.json.bak

COPY --from=build /out/cfdata /usr/local/bin/cfdata
WORKDIR /data
ENV TZ=Asia/Shanghai
USER cfdata:cfdata
EXPOSE 13335
ENTRYPOINT ["/usr/local/bin/cfdata"]
CMD ["-host", "0.0.0.0", "-port", "13335"]
