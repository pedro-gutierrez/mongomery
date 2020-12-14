defmodule Mongomery.Application do
  use Application
  alias Mongomery.Http
  alias Mongomery.Streams
  alias Mongomery.Mongo

  @port 8080

  @routes %{
    "/" => Mongomery.Http.Health,
    "/events" => Mongomery.Http.Events,
    "/test" => Mongomery.Http.Test
  }

  def start(_, _) do
    callback_url = System.fetch_env!("CALLBACK_URL")

    start =
      [
        {Http, [@port, @routes]},
        Mongo.Supervisor,
        {Streams.Supervisor, [callback_url: callback_url]}
      ]
      |> Supervisor.start_link(strategy: :one_for_one, name: Mongomery.Supervisor)

    Mongomery.Streams.resolve!()
    start
  end

  def test() do
    :httpc.request(
      :post,
      {'http://localhost:8080/events', [], 'application/json',
       Jason.encode!(%{"stream" => "events_created", "id" => "abc"})},
      [],
      []
    )
  end
end
