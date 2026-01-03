
# Build stage
FROM hexpm/elixir:1.18.0-erlang-26.2.5.3-alpine-3.19.4 AS builder

# Install build dependencies
RUN apk add --no-cache build-base git

# Prepare build directory
WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set build environment
ENV MIX_ENV=prod

# Install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod
RUN mix deps.compile

# Copy compile-time config files
COPY config/config.exs config/prod.exs config/
COPY config/runtime.exs config/

# Copy source code
COPY lib lib
COPY priv priv

# Compile the release
RUN mix compile

# Build the release
RUN mix release

# ----------------------------------------------------------------------------

# Runtime stage
FROM alpine:3.19 AS runner

# Install runtime dependencies
RUN apk add --no-cache libstdc++ openssl ncurses-libs

# Set runtime environment
ENV MIX_ENV=prod
ENV PORT=4000

# Create a non-root user
WORKDIR /app
RUN adduser -D diwa && chown diwa:diwa /app
USER diwa

# Copy the release from the builder
COPY --from=builder --chown=diwa:diwa /app/_build/prod/rel/diwa_agent ./

# Docker healthcheck (optional, but good practice)
# Identifying the port is standard.
EXPOSE 4000

# Start command
CMD ["bin/diwa_agent", "start"]
