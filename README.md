# Mongomery

A simple, http driven store written in Elixir and backed by MongoDB.

## Create a stream

```
$ export TOKEN=...
$ curl -X POST \
  -H "authorization: Bearer $TOKEN" \
  -H "content-type: application/json" \
  -d '[{ "name" : "user_created", "callback: "http://localhost:8080/callback" }]' \
  https://mongomery-pedro-gutierrez.okteto.net"
```

## Post an event


```
$ export TOKEN=...
$ curl -X POST \
  -H "authorization: Bearer $TOKEN" \
  -H "content-type: application/json" \
  -d '{ "stream" : "user_created", "username": "foo" }]' \
  https://mongomery-pedro-gutierrez.okteto.net"
```
