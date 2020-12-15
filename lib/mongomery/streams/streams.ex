defmodule Mongomery.Streams do
  @topology :info

  def all() do
    Mongo.find(@topology, "streams", %{})
    |> Stream.map(fn s -> Map.drop(s, ["_id"]) end)
    |> Enum.to_list()
  end

  def start!() do
    all()
    |> Enum.map(fn %{"name" => name} -> name end)
    |> Enum.each(&Mongomery.Streams.Supervisor.start!(&1))
  end
end
