FROM golang:1.24-alpine AS builder

WORKDIR /app

COPY go.mod go.sum* ./
RUN go mod download || true

COPY . .

ARG SERVICE=api
RUN CGO_ENABLED=0 GOOS=linux go build -o /app/bin/service ./cmd/${SERVICE}

FROM alpine:3.19

RUN apk --no-cache add ca-certificates tzdata

WORKDIR /root/
COPY --from=builder /app/bin/service .

EXPOSE 8080
ENTRYPOINT ["./service"]

