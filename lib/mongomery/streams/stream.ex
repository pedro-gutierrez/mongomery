defmodule Mongomery.Streams.Stream do
  use GenServer
  require Logger

  def pid(stream) do
    :global.whereis_name({:stream, stream})
  end

  def write(%{"stream" => stream} = event) do
    t0 = :os.system_time(:microsecond)

    Mongomery.Streams.Supervisor.start!(stream)
    t1 = :os.system_time(:microsecond)

    event =
      event
      |> Map.drop(["_id", "stream"])
      |> Map.put("_s", 1)

    {:ok, _} = Mongo.insert_one(:writer, stream, event)
    t2 = :os.system_time(:microsecond)

    poll(stream)
    t3 = :os.system_time(:microsecond)

    IO.inspect(start: t1 - t0, write: t2 - t1, poll: t3 - t2)
    :ok
  end

  def poll(stream) do
    GenServer.call({:global, {:stream, stream}}, :next)
  end

  def start_link(opts, stream) do
    opts =
      opts
      |> Keyword.merge(stream: stream)
      |> Enum.into(%{})

    GenServer.start_link(__MODULE__, opts, name: {:global, {:stream, stream}})
  end

  def init(%{stream: stream} = state) do
    state = Map.put(state, :status, :active)
    ensure_index!(stream)
    update!(stream, state.status)
    Logger.debug("Started stream #{stream}")
    {:ok, state, {:continue, :next}}
  end

  def handle_continue(:next, state) do
    next(state)
  end

  def handle_info(:next, state) do
    next(state)
  end

  def handle_call(:next, _, %{status: :idle} = state) do
    schedule(0)
    {:reply, :ok, state}
  end

  def handle_call(:next, _, state) do
    {:reply, :ok, state}
  end

  defp schedule(wait \\ 1000) do
    Process.send_after(self(), :next, wait)
  end

  defp next(%{stream: stream, callback_url: url} = state) do
    with %{"_id" => id} = doc <-
           Mongo.find_one(:poller, stream, %{"_s" => 1}, sort: %{"_id" => 1}) do
      case notify(stream, doc, url) do
        :ok ->
          {:ok, %{modified_count: 1}} =
            Mongo.update_one(:poller, stream, %{"_id" => id}, %{
              "$set" => %{"_s" => 2}
            })

          {:noreply, %{state | status: :active}, {:continue, :next}}

        :error ->
          schedule()
          {:noreply, %{state | status: :retrying}}
      end
    else
      _ ->
        {:noreply, %{state | status: :idle}}
    end
  end

  @meta_attrs ["_id", "_s"]

  defp notify(stream, event, url) do
    event =
      event
      |> Map.drop(@meta_attrs)
      |> Map.put(:stream, stream)

    case HTTPoison.post(
           url,
           Jason.encode!(event),
           [{"Content-Type", "application/json"}]
         ) do
      {:ok, %{status_code: 200}} ->
        :ok

      {:ok, %{status_code: code}} ->
        Logger.warn("Unexpected status code #{code} from #{url}")
        :error

      {:error, e} ->
        Logger.warn("Unexpected error #{inspect(e)} from #{url}")
        :error
    end
  end

  defp ensure_index!(stream) do
    {:ok, _} =
      Mongo.command(
        :poller,
        [
          createIndexes: stream,
          indexes: [
            [name: "_s_", unique: false, key: [_s: 1]]
          ]
        ],
        []
      )

    :ok
  end

  defp update!(stream, status) do
    {:ok, _} =
      Mongo.update_one(
        :poller,
        "streams",
        %{"name" => stream, "status" => status},
        %{"$currentDate" => %{"since" => true}},
        upsert: true
      )

    :ok
  end
end
