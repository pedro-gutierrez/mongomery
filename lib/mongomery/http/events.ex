defmodule Mongomery.Http.Events do
  def on(event) do
    Mongomery.Streams.Stream.write(event)
  end
end
