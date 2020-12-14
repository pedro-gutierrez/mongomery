defmodule Mongomery.Streams.Poller do
  use GenServer
  require Logger

  @topology :poller

  def poll(stream) do
    GenServer.cast({:global, {:poller, stream}}, :next)
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: {:global, {:poller, opts[:stream]}})
  end

  def init(opts) do
    opts = Keyword.merge(opts, status: :idle)
    {:ok, Enum.into(opts, %{}), {:continue, :next}}
  end

  def handle_continue(:next, state) do
    next(state)
  end

  def handle_info(:next, state) do
    next(state)
  end

  def handle_cast(:next, %{status: :idle} = state) do
    next(state)
  end

  def handle_cast(:next, state) do
    {:noreply, state}
  end

  defp schedule(wait \\ 1000) do
    Process.send_after(self(), :next, wait)
  end

  defp next(%{stream: stream, callback_url: url} = state) do
    with %{"_id" => id} = doc <-
           Mongo.find_one(@topology, stream, %{"_s" => 1}, sort: %{"_id" => 1}) do
      case notify(stream, doc, url) do
        :ok ->
          {:ok, %{modified_count: 1}} =
            Mongo.update_one(@topology, stream, %{"_id" => id}, %{
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
end
