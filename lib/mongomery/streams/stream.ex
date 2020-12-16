defmodule Mongomery.Streams.Stream do
  use GenServer
  require Logger
  alias Mongomery.Slack

  def pid(stream) do
    :global.whereis_name({:stream, stream})
  end

  def write([_ | _] = events) do
    {streams, events} =
      Enum.map(events, fn %{"stream" => stream} = event ->
        {stream,
         event
         |> Map.drop(["_id", "stream"])
         |> Map.put("_s", 1)}
      end)
  end

  def write(%{"stream" => stream} = event) do
    Mongomery.Streams.Supervisor.start!(stream)

    event =
      event
      |> Map.drop(["_id", "stream"])
      |> Map.put("_s", 1)

    {:ok, _} = Mongo.insert_one(:writer, stream, event)

    poll!(stream)

    :ok
  end

  def poll!(stream) do
    :ok = GenServer.call({:global, {:stream, stream}}, :next)
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

  defp next(
         %{stream: stream, callback_url: url, slack_url: slack_url, client_secret: client_secret} =
           state
       ) do
    with %{"_id" => _} = doc <- next_event(stream) do
      case notify(stream, doc, url, client_secret, slack_url) do
        :ok ->
          done!(stream, doc)
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

  defp next_event(stream) do
    Mongo.find_one(:poller, stream, %{"_s" => 1}, sort: %{"_id" => 1})
  end

  defp done!(stream, %{"_id" => id}) do
    {:ok, %{modified_count: 1}} =
      Mongo.update_one(:poller, stream, %{"_id" => id}, %{
        "$set" => %{"_s" => 2}
      })
  end

  defp notify(stream, event, url, client_secret, slack_url) do
    event =
      event
      |> Map.drop(@meta_attrs)
      |> Map.put(:stream, stream)

    with {:error, e} <- Mongomery.Http.post(url, event, auth: client_secret) do
      Slack.error(
        slack_url,
        "Got `#{inspect(e)}` when calling `#{url}` from stream `#{stream}`"
      )

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
