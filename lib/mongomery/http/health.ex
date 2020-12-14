defmodule Mongomery.Http.Health do
  def on(_) do
    {:ok, %{"streams" => Mongomery.Streams.all()}}
  end
end
