FROM pedrogutierrez/elixir:1.11 AS builder
RUN apk add build-base curl

RUN mkdir -p /app
WORKDIR /app
ADD lib /app/lib
ADD mix.exs /app
ADD mix.lock /app

ENV MIX_ENV prod

RUN mix local.hex --force && \
    mix local.rebar && \
    mix deps.get && \
    mix release

FROM pedrogutierrez/elixir:1.11

RUN mkdir -p /app
WORKDIR /app
COPY --from=builder /app/_build/prod /app
CMD [ "/app/rel/mongomery/bin/mongomery", "start" ]
