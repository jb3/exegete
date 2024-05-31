defmodule Exegete.MixProject do
  use Mix.Project

  def project do
    [
      app: :exegete,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Exegete.Application, []}
    ]
  end

  defp deps do
    []
  end
end
