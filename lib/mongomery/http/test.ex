defmodule Mongomery.Http.Test do
  def on(event) do
    IO.inspect(received: event)
    :ok
  end

  def test() do
    :httpc.request(
      :post,
      {'http://localhost:8080/events', [], 'application/json',
       Jason.encode!(%{"stream" => "events_created", "id" => "abc"})},
      [],
      []
    )
  end
end
