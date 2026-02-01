FROM elixir:1.16-alpine AS build

# Install build dependencies
RUN apk add --no-cache build-base git

# Set working directory
WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Copy mix files
COPY mix.exs mix.lock ./

# Install dependencies
RUN mix deps.get --only prod && \
    mix deps.compile

# Copy application code
COPY . .

# Compile application
RUN mix compile

# Build release
RUN mix release

# ==========================================
# Final stage
# ==========================================
FROM alpine:3.18

# Install runtime dependencies
RUN apk add --no-cache \
    ncurses-libs \
    libstdc++ \
    openssl

# Create app directory
WORKDIR /app

# Create non-root user
RUN addgroup -g 1000 skulldb && \
    adduser -D -u 1000 -G skulldb skulldb

# Copy release from build stage
COPY --from=build --chown=skulldb:skulldb /app/_build/prod/rel/skulldb ./

# Create data directory
RUN mkdir -p /data && chown -R skulldb:skulldb /data

# Switch to non-root user
USER skulldb

# Environment variables
ENV SKULLDB_DATA_DIR=/data
ENV SKULLDB_HTTP_PORT=4000
ENV HOME=/app

# Expose HTTP port
EXPOSE 4000

# Volume for data persistence
VOLUME ["/data"]

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:4000/health || exit 1

# Start the application
CMD ["./bin/skulldb", "start"]
