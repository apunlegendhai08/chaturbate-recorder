FROM golang:1.24-alpine AS builder
WORKDIR /workspace

ENV GOTOOLCHAIN=local
ENV GOPROXY=https://proxy.golang.org,direct
ENV GOPRIVATE=""

# Install build dependencies
RUN apk add --no-cache git ca-certificates

# Copy go mod files first for better caching
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY ./ ./

# Build with retry logic
RUN go build -ldflags="-s -w" -o goondvr . || \
    (echo "Build failed, retrying..." && sleep 5 && go build -ldflags="-s -w" -o goondvr .)

FROM alpine:3 AS runnable
RUN apk --no-cache add ca-certificates ffmpeg
WORKDIR /usr/src/app

COPY --from=builder /workspace/goondvr /goondvr

ENTRYPOINT ["/goondvr"]
