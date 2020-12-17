defmodule Mongomery.Application do
  use Application
  alias Mongomery.Http
  alias Mongomery.Streams
  alias Mongomery.Mongo

  @port 8080

  @routes %{
    "/" => Mongomery.Http.Health,
    "/streams" => Mongomery.Http.Streams,
    "/events" => Mongomery.Http.Events
  }

  def start(_, _) do
    callback_url = System.fetch_env!("CALLBACK_URL")
    slack_url = System.fetch_env!("SLACK_URL")
    server_secret = System.fetch_env!("SERVER_SECRET")
    client_secret = System.fetch_env!("CLIENT_SECRET")

    start =
      [
        {Http, [@port, @routes, server_secret]},
        Mongo.Supervisor,
        {Streams.Supervisor,
         [callback_url: callback_url, slack_url: slack_url, client_secret: client_secret]}
      ]
      |> Supervisor.start_link(strategy: :one_for_one, name: Mongomery.Supervisor)

    Mongomery.Streams.start!()
    start
  end
end
