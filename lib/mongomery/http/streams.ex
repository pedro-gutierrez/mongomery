defmodule Mongomery.Http.Streams do
  @moduledoc """
  This handler accepts a list of stream
  metadata and provisions them.
  """

  def auth?(), do: true

  def on(streams) do
    Mongomery.Streams.create!(streams)
  end
end
