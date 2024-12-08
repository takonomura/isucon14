FROM golang:1.23

WORKDIR /src
COPY . .
RUN go build -o /payment_mock .
CMD ["/payment_mock"]
