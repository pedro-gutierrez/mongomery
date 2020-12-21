defmodule Mongomery.Streams do
  def all() do
    Mongo.find(:info, "streams", %{})
    |> Stream.map(fn s -> Map.drop(s, ["_id"]) end)
    |> Enum.to_list()
  end

  def all?(streams) do
    sorted = Enum.sort(streams)

    case Mongo.find(:info, "streams", %{"name" => %{"$in" => streams}})
         |> Enum.to_list()
         |> Enum.map(fn %{"name" => name} -> name end)
         |> Enum.sort() do
      ^sorted -> true
      _ -> false
    end
  end

  def create!(streams) do
    streams =
      Enum.filter(streams, fn
        %{"name" => _, "callback" => _} -> true
        _ -> false
      end)

    {:ok, _} =
      Mongo.Session.with_transaction(
        :info,
        fn _ ->
          Enum.each(streams, fn stream ->
            {:ok, _} =
              Mongo.command(
                :info,
                [
                  createIndexes: stream["name"],
                  indexes: [
                    [name: "_s_", unique: false, key: [_s: 1]]
                  ]
                ],
                []
              )

            {:ok, _} =
              Mongo.update_one(
                :info,
                "streams",
                %{"name" => stream["name"]},
                %{
                  "$set" => %{
                    "retries" => stream["retries"] || 10,
                    "sleep" => stream["sleep"] || 1000,
                    "callback" => stream["callback"],
                    "status" => "idle"
                  }
                },
                upsert: true
              )
          end)

          {:ok, length(streams)}
        end,
        transaction_retry_timeout_s: 10
      )

    Enum.each(streams, fn %{"name" => name} ->
      Mongomery.Streams.Supervisor.stop!(name)
      Mongomery.Streams.Supervisor.start!(name)
    end)

    {:ok, streams}
  end

  def start!() do
    all()
    |> Enum.map(fn %{"name" => name} -> name end)
    |> Enum.each(&Mongomery.Streams.Supervisor.start!(&1))
  end

  def info!(stream) do
    with nil <- Mongo.find_one(:info, "streams", %{"name" => stream}) do
      raise "stream #{stream} not found"
    end
  end
end
