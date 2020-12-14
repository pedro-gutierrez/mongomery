defmodule Mongomery.Streams.Stream do
  use Supervisor

  alias Mongomery.Streams.Writer
  alias Mongomery.Streams.Poller

  def start_link(opts, stream) do
    opts = Keyword.merge(opts, stream: stream)
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    [{Writer, opts}, {Poller, opts}]
    |> Supervisor.init(strategy: :one_for_one)
  end
end
