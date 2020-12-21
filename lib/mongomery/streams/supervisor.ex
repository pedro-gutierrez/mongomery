defmodule Mongomery.Streams.Supervisor do
  use DynamicSupervisor
  alias Mongomery.Streams.Stream

  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    DynamicSupervisor.init(
      strategy: :one_for_one,
      extra_arguments: [opts]
    )
  end

  def start!(stream) do
    with :undefined <- Stream.pid(stream) do
      case DynamicSupervisor.start_child(__MODULE__, {Stream, stream}) do
        {:ok, _} -> :ok
        {:error, {:already_started, _}} -> :ok
      end
    end

    :ok
  end

  def stop!(stream) do
    with pid when is_pid(pid) <- Stream.pid(stream) do
      Process.exit(pid, :shutdown)
    end
  end
end
