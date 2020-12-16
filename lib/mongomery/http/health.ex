defmodule Mongomery.Http.Health do
  def auth?(), do: false

  def on(_) do
    {:ok, %{"streams" => Mongomery.Streams.all()}}
  end
end
