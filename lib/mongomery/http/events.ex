defmodule Mongomery.Http.Events do
  def auth?(), do: true

  def on(events) do
    Mongomery.Streams.Stream.write(events)
  end
end
