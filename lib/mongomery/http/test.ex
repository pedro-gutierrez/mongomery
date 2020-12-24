defmodule Mongomery.Http.Test do
  def auth?(), do: false

  def post(%{"force" => "retry"}) do
    {503, %{},
     %{
       "retry-after" => "2000"
     }}
  end

  def post(_) do
    :ok
  end
end
