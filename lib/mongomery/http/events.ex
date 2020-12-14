defmodule Mongomery.Http.Events do
  def on(event) do
    Mongomery.Streams.Writer.write(event)
  end
end
