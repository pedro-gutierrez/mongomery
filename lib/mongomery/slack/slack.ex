defmodule Mongomery.Slack do
  require Logger

  def error(url, text) do
    body = %{
      "attachments" => [
        %{
          "color" => "danger",
          "text" => text
        }
      ]
    }

    with {:error, e} <-
           Mongomery.Http.post(url, body) do
      Logger.warn("Got #{inspect(e)} when calling slack. Original error: #{text}")
    end

    :ok
  end
end
