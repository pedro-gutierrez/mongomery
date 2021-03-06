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

      method = method(req)

      {status, body, headers} =
        case apply(mod, method, [body]) do
          :ok ->
            {200, %{}, %{}}

          {:ok, data} ->
            {200, data, %{}}

          {:error, :invalid} ->
            {400, %{}, %{}}

          {:error, other} ->
            {500, other, %{}}

          other ->
            other
        end

      reply(req, start, status, body, headers)
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

  @default_retry 1000

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

      {:ok, %{status_code: code, headers: headers, body: body}} ->
        headers = Enum.into(headers, %{})
        retry = int_header(headers, "retry-after", @default_retry)

        body =
          case Jason.decode(body) do
            {:ok, doc} -> doc
            {:error, _} -> body
          end

        {:error, code, retry: retry, response: %{status: code, headers: headers, body: body}}

      {:error, %{reason: e}} ->
        {:error, e, []}
    end
  end

  defp method(%{method: m}) do
    method(m)
  end

  defp method("GET"), do: :get
  defp method("POST"), do: :post
  defp method("DELETE"), do: :delete
  defp method("PUT"), do: :put

  defp int_header(headers, key, default) do
    case headers[key] do
      nil ->
        default

      header ->
        case Integer.parse(header) do
          {header, _} ->
            header

          :error ->
            default
        end
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
    reply(req, start, 401, %{}, %{})
  end

  defp check_token(req, secret, secret, _) do
    {:continue, req}
  end

  defp check_token(req, _, _, start) do
    reply(req, start, 401, %{}, %{})
  end

  defp reply(req, start, status, body, headers) do
    headers =
      Map.merge(
        headers,
        %{
          "content-type" => "application/json",
          "duration" => "#{:os.system_time(:microsecond) - start}"
        }
      )

    {:ok,
     :cowboy_req.reply(
       status,
       headers,
       Jason.encode!(body),
       req
     ), []}
  end
end
