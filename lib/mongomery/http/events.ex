defmodule Mongomery.Http.Events do
  def on(events) do
    Mongomery.Streams.Stream.write(events)
  end
end
