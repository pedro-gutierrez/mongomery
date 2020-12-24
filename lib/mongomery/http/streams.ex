defmodule Mongomery.Http.Streams do
  @moduledoc """
  This handler accepts a list of stream
  metadata and provisions them.
  """

  alias Mongomery.Streams
  alias Mongomery.Streams.Stream

  def auth?(), do: true

  def post(streams) do
    Streams.create!(streams)
  end

  def get(_) do
    streams =
      Streams.all()
      |> Enum.map(fn %{"name" => name} = stream ->
        Map.merge(stream, %{
          "node" => Stream.location(name),
          "pending" => Stream.pending!(name),
          "errors" => Stream.errors!(name),
          "done" => Stream.done!(name)
        })
      end)

    {:ok, streams}
  end
end
