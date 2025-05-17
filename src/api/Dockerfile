# Use the official Golang image as the build stage
FROM golang:1.24.3 AS builder

ENV CGO_ENABLED=0 GOOS=linux GOARCH=amd64

# Set the working directory inside the container
WORKDIR /app

# Copy the go.mod and go.sum files
COPY go.mod go.sum ./

# Download the dependencies
RUN go mod download

# Copy the source code into the container
COPY . .

# Build the Go application as a single binary
RUN go build -a -ldflags="-s -w" -o main .

# Use a lightweight base image for the final container
FROM scratch

# Copy the binary from the builder stage
COPY --from=builder /app/main /main

# Define the environment variable for the application
ENV GIN_MODE=release

# Expose the required port
EXPOSE 8080

# Command to run the application
CMD ["/main"]
