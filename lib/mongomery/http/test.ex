defmodule Mongomery.Http.Test do
  def auth?(), do: false

  def on(_) do
    {503, %{},
     %{
       "retry-after" => "2000"
     }}
  end
end
