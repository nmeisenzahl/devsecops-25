# Use the official Golang image as the build stage
FROM golang:1.25.3 AS builder

ENV CGO_ENABLED=0 GOOS=linux GOARCH=amd64

# Set the working directory inside the container
WORKDIR /app

# Copy the go.mod and go.sum files
COPY go.mod go.sum ./

# Download the dependencies
RUN go mod download
# Install CA certificates for TLS validation
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*

# Copy the source code into the container
COPY . .

# Build the Go application as a single binary
RUN go build -a -ldflags="-s -w" -o main .

# Use a lightweight base image for the final container
FROM scratch

# Copy CA certificate store from builder
COPY --from=builder /etc/ssl/certs /etc/ssl/certs
# Copy the binary from the builder stage
COPY --from=builder /app/main /main

# Define the environment variable for the application
ENV GIN_MODE=release

# Expose the required port
EXPOSE 8080

# Command to run the application
CMD ["/main"]
