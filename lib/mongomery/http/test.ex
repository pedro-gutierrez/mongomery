defmodule Mongomery.Http.Test do
  def on(event) do
    IO.inspect(received: event)
    :ok
  end
end
