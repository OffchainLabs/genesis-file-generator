# syntax=docker/dockerfile:1
FROM ghcr.io/foundry-rs/foundry:v1.4.2

# Copy code into container
WORKDIR /app
COPY . .

# Copy environment variables file
COPY .env.example .env

# Create genesis output directory if it doesn't exist
# Note: we change the owner of the directory in case it already existed under root
# (because for example, this is being built from a github repository)
RUN mkdir -p genesis
USER 0
RUN chown -R foundry:foundry genesis
USER foundry
