defmodule Mongomery.Streams.Supervisor do
  use DynamicSupervisor
  alias Mongomery.Streams.Writer
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

  def resolve!(stream) do
    with :undefined <- Writer.pid?(stream) do
      {:ok, _} = DynamicSupervisor.start_child(__MODULE__, {Stream, stream})
    end

    :ok
  end
end
