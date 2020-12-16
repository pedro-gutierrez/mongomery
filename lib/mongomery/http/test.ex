defmodule Mongomery.Http.Test do
  def on(event) do
    IO.inspect(received: event)
    :ok
  end

  def test() do
    Mongomery.Http.post(
      "http://localhost:8080/events",
      [
        %{"stream" => "events_created", "id" => "abc"},
        %{"stream" => "events_resolved", "id" => "def"}
      ],
      auth: "whatever"
    )
  end
end
