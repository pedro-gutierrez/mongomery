defmodule Mongomery.Http do
  def init(req, mod) do
    start = :os.system_time(:microsecond)

    {req, body} =
      case :cowboy_req.has_body(req) do
        true ->
          {:ok, data, req} = :cowboy_req.read_body(req)
          {req, Jason.decode!(data)}

        false ->
          {req, nil}
      end

    {status, body} =
      case mod.on(body) do
        :ok ->
          {200, %{}}

        {:ok, data} ->
          {200, data}

        {:error, :invalid} ->
          {400, %{}}

        {:error, other} ->
          {500, other}
      end

    body = Jason.encode!(body)
    stop = :os.system_time(:microsecond)

    req =
      :cowboy_req.reply(
        status,
        %{
          "content-type" => "application/json",
          "duration" => "#{stop - start}"
        },
        body,
        req
      )

    {:ok, req, []}
  end

  def start_link([port, routes]) do
    routes =
      Enum.map(routes, fn {path, mod} ->
        {path, __MODULE__, mod}
      end)

    :cowboy.start_clear(
      "http",
      %{
        num_acceptors: :erlang.system_info(:schedulers),
        socket_opts: [port: port]
      },
      %{
        :env => %{
          :dispatch =>
            :cowboy_router.compile([
              {:_, routes}
            ])
        }
      }
    )
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end
end
