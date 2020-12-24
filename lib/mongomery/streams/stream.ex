defmodule Mongomery.Streams.Stream do
  use GenServer
  require Logger
  alias Mongomery.Slack

  def pid(stream) do
    :global.whereis_name({:stream, stream})
  end

  def location(stream) do
    case Mongomery.Streams.Stream.pid(stream) do
      :undefined ->
        :none

      pid ->
        node(pid)
    end
  end

  def pending!(stream), do: count!(stream, 1)
  def errors!(stream), do: count!(stream, 3)
  def done!(stream), do: count!(stream, 2)

  defp count!(stream, status) do
    {:ok, count} = Mongo.count_documents(:info, stream, %{"_s" => status})
    count
  end

  def write([_ | _] = events) do
    streams =
      events
      |> Enum.map(fn %{"stream" => stream} ->
        stream
      end)
      |> Enum.uniq()

    case Mongomery.Streams.all?(streams) do
      false ->
        {:error, :invalid}

      true ->
        {:ok, _} =
          Mongo.Session.with_transaction(
            :writer,
            fn opts ->
              Enum.each(events, fn %{"stream" => stream} = event ->
                event =
                  event
                  |> Map.drop(["_id", "stream"])
                  |> Map.put("_s", 1)

                {:ok, %{:inserted_id => _}} = Mongo.insert_one(:writer, stream, event, opts)
              end)

              {:ok, length(events)}
            end,
            transaction_retry_timeout_s: 10
          )

        Enum.each(streams, &poll!(&1))
        :ok
    end
  end

  def write(event) when is_map(event) do
    write([event])
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
    %{"callback" => url, "retries" => retries, "sleep" => sleep} = Mongomery.Streams.info!(stream)

    status = :active
    update_stream!(stream, status)

    state =
      state
      |> Map.merge(%{
        status: status,
        callback_url: url,
        max_retries: retries,
        retries_left: retries,
        retry_sleep: sleep,
        last_error: nil
      })

    Logger.debug("Started stream #{stream}")
    {:ok, state, {:continue, :next}}
  end

  def handle_continue(:next, state) do
    next(state)
  end

  def handle_info(:next, state) do
    next(state)
  end

  def handle_info({:retry, doc}, state) do
    retry(doc, state)
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  def handle_call(:next, _, %{status: :idle} = state) do
    schedule(0)
    {:reply, :ok, state}
  end

  def handle_call(_, _, state) do
    {:reply, :ok, state}
  end

  @meta_attrs ["_id", "_s", "_e"]

  defp schedule(wait) do
    Process.send_after(self(), :next, wait)
  end

  defp next(
         %{
           stream: stream,
           max_retries: max_retries
         } = state
       ) do
    case next_event(stream) do
      %{"_id" => _} = doc ->
        notify_with_retry(doc, %{state | retries_left: max_retries})

      _ ->
        update_stream!(stream, :idle)
        {:noreply, %{state | status: :idle}}
    end
  end

  def retry(
        doc,
        %{
          stream: stream,
          retries_left: 0,
          slack_url: slack_url,
          callback_url: url,
          last_error: e
        } = state
      ) do
    set_doc_error!(stream, doc, e)

    Slack.error(
      slack_url,
      "Got `#{inspect(e)}` when calling `#{url}` from stream `#{stream}`"
    )

    {:noreply, %{state | status: :active, last_error: nil}, {:continue, :next}}
  end

  def retry(doc, state) do
    notify_with_retry(doc, state)
  end

  defp notify_with_retry(
         doc,
         %{
           stream: stream,
           callback_url: url,
           client_secret: client_secret,
           retry_sleep: retry_sleep,
           retries_left: retries_left
         } = state
       ) do
    case notify(stream, doc, url, client_secret) do
      :ok ->
        set_doc_status!(stream, doc, 2)
        {:noreply, %{state | status: :active}, {:continue, :next}}

      {:error, e, opts} ->
        retry_after = opts[:retry] || retry_sleep
        error = opts[:response] || e

        Process.send_after(self(), {:retry, doc}, retry_after)

        Logger.warn(
          "Retrying delivery to #{url} in #{retry_after}ms after #{inspect(e)} in stream #{stream}"
        )

        {:noreply,
         %{
           state
           | status: :retrying,
             last_error: error,
             retries_left: retries_left - 1
         }}
    end
  end

  defp next_event(stream) do
    Mongo.find_one(:poller, stream, %{"_s" => 1}, sort: %{"_id" => 1})
  end

  defp set_doc_status!(stream, %{"_id" => id}, status) do
    {:ok, %{modified_count: 1}} =
      Mongo.update_one(:poller, stream, %{"_id" => id}, %{
        "$set" => %{"_s" => status}
      })
  end

  defp set_doc_error!(stream, %{"_id" => id}, error) do
    {:ok, %{modified_count: 1}} =
      Mongo.update_one(:poller, stream, %{"_id" => id}, %{
        "$set" => %{"_s" => 3, "_e" => error}
      })
  end

  defp notify(stream, event, url, client_secret) do
    event =
      event
      |> Map.drop(@meta_attrs)
      |> Map.put(:stream, stream)

    Mongomery.Http.post(url, event, auth: client_secret)
  end

  defp update_stream!(stream, status) do
    {:ok, %{modified_count: 1}} =
      Mongo.update_one(:info, "streams", %{"name" => stream}, %{
        "$set" => %{"status" => status},
        "$currentDate" => %{"since" => true}
      })
  end
end
