defmodule Mongomery.Http do
  def init(req, [mod, secret]) do
    start = :os.system_time(:microsecond)

    with {:continue, req} <- auth(mod, req, secret, start) do
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

      reply(req, start, status, body)
    end
  end

  def start_link([port, routes, secret]) do
    routes =
      routes
      |> Enum.map(fn {path, mod} ->
        {path, __MODULE__, [mod, secret]}
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

  def post(url, body, opts \\ []) do
    headers = [{"Content-Type", "application/json"}]

    headers =
      case opts[:auth] do
        nil ->
          headers

        token ->
          [{"Authorization", "Bearer #{token}"} | headers]
      end

    case HTTPoison.post(
           url,
           Jason.encode!(body),
           headers
         ) do
      {:ok, %{status_code: code}} when code >= 200 and code < 300 ->
        :ok

      {:ok, %{status_code: code}} ->
        {:error, code}

      {:error, %{reason: e}} ->
        {:error, e}
    end
  end

  defp auth(mod, req, secret, start) do
    case mod.auth?() do
      true ->
        auth(req, secret, start)

      false ->
        {:continue, req}
    end
  end

  defp auth(%{headers: %{"authorization" => "Bearer " <> token}} = req, secret, start) do
    check_token(req, :crypto.hash(:sha256, token) |> Base.encode16(), secret, start)
  end

  defp auth(req, _, start) do
    reply(req, start, 401)
  end

  defp check_token(req, secret, secret, _) do
    {:continue, req}
  end

  defp check_token(req, _, _, start) do
    reply(req, start, 401)
  end

  defp reply(req, start, status, body \\ %{}) do
    {:ok,
     :cowboy_req.reply(
       status,
       %{
         "content-type" => "application/json",
         "duration" => "#{:os.system_time(:microsecond) - start}"
       },
       Jason.encode!(body),
       req
     ), []}
  end
end
