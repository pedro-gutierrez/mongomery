defmodule Mongomery.MixProject do
  use Mix.Project

  def project do
    [
      app: :mongomery,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      applications: [
        :cowboy,
        :jason,
        :mongodb_driver,
        :ranch,
        :uuid,
        :httpoison
      ],
      mod: {Mongomery.Application, []}
    ]
  end

  defp deps do
    [
      {:mongodb_driver, "~> 0.7.0"},
      {:libcluster, "~> 3.2"},
      {:cowboy, "~> 2.8.0"},
      {:jason, "~> 1.2"},
      {:uuid, "~> 1.1"},
      {:httpoison, "~> 1.6"}
    ]
  end
end
