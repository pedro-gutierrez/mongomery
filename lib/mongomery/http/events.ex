defmodule Mongomery.Http.Events do
  def auth?(), do: true

  def post(events) do
    Mongomery.Streams.Stream.write(events)
  end
end
