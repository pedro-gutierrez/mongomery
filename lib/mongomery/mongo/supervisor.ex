defmodule Mongomery.Mongo.Supervisor do
  use Supervisor

  @names [:writer, :poller, :info]

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_) do
    System.fetch_env!("MONGO_URL")
    |> connections(@names)
    |> Supervisor.init(strategy: :one_for_one)
  end

  def connections(url, names) do
    Enum.map(names, fn name ->
      %{
        id: name,
        start:
          {Mongo, :start_link,
           [
             [
               timeout: 5000,
               pool_timeout: 8000,
               name: name,
               url: url,
               pool_size: 1
             ]
           ]},
        type: :worker,
        restart: :permanent,
        shutdown: 5000
      }
    end)
  end
end
