defmodule Mongomery.Slack do
  require Logger

  def error(url, stream, text) do
    body = %{
      "attachments" => [
        %{
          "color" => "danger",
          "text" => "Error in stream `#{stream}`: #{text}"
        }
      ]
    }

    with {:ok, %{status_code: 200}} <-
           HTTPoison.post(
             url,
             Jason.encode!(body),
             [{"Content-Type", "application/json"}]
           ) do
      :ok
    else
      other ->
        Logger.warn("Error notying error in stream #{stream}: #{inspect(other)}")
    end
  end
end
