FROM elixir:1.19-alpine AS build

# Install build dependencies
RUN apk add --no-cache \
    openssl-dev \
    openssl \
    build-base \
    git

# Set working directory
WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Copy mix files
COPY mix.exs mix.lock ./

ENV MIX_ENV=prod

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
# Use the same base as build to avoid OpenSSL ABI mismatch
FROM elixir:1.19-alpine

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

<<<<<<< HEAD
# Volume for data persistence
=======
# Note: VOLUME removed for Railway compatibility
# Railway manages volumes differently - use Railway volumes if persistence is needed
>>>>>>> c311452 (fixed docker issues and adapted for deploy on Railway.)
# VOLUME ["/data"]

# Health check (Railway may ignore this, but kept for local development)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:4000/health || exit 1

# Start the application
CMD ["./bin/skulldb", "start"]
