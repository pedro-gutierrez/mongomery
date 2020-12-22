defmodule Mongomery.Http.Health do
  def auth?(), do: false

  def get(_) do
    :ok
  end
end
