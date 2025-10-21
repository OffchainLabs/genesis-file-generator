# syntax=docker/dockerfile:1
FROM ghcr.io/foundry-rs/foundry:v1.4.2

# Copy code into container
WORKDIR /app
COPY . .

# Copy environment variables file
COPY .env.example .env

# Create genesis output directory if it doesn't exist
RUN mkdir -p genesis

# Execute generate script
ENTRYPOINT ["./generate.sh"]