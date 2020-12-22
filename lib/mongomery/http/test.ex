defmodule Mongomery.Http.Test do
  def auth?(), do: false

  def post(_) do
    {503, %{},
     %{
       "retry-after" => "2000"
     }}
  end
end
