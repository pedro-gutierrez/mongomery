defmodule Mongomery.Streams.Writer do
  use GenServer

  @topology :writer

  def pid?(name) do
    :global.whereis_name({:writer, name})
  end

  def write(%{"stream" => stream} = event) do
    Mongomery.Streams.Supervisor.resolve!(stream)
    GenServer.call({:global, {:writer, stream}}, {:write, event})
  end

  def resume!(stream) do
    update!(stream, "active")
  end

  defp update!(stream, status) do
    {:ok, _} =
      Mongo.update_one(
        @topology,
        "streams",
        %{"name" => stream, "status" => status},
        %{"$currentDate" => %{"since" => true}},
        upsert: true
      )

    :ok
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: {:global, {:writer, opts[:stream]}})
  end

  def init(opts) do
    stream = opts[:stream]
    resume!(stream)
    {:ok, %{stream: stream}}
  end

  def handle_call({:write, event}, _, %{stream: stream} = state) do
    event =
      event
      |> Map.drop(["_id", "stream"])
      |> Map.put("_s", 1)

    {:ok, _} = Mongo.insert_one(@topology, stream, event)
    Mongomery.Streams.Poller.poll(stream)
    {:reply, :ok, state}
  end
end
