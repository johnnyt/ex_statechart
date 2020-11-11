defmodule StateChart.Mixfile do
  use Mix.Project

  def project do
    [
      app: :state_chart,
      version: "0.1.0",
      elixir: "~> 1.3",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [applications: [:logger]]
  end

  defp deps do
    [
      {:tesla, "~> 1.3", only: [:dev, :test]},
      {:etude, "~> 1.0", only: [:dev, :test]},
      {:etude_request, "~> 0.2", only: [:dev, :test]},
      {:poison, ">= 3.0.0", only: [:dev, :test]},
      {:mix_test_watch, ">= 0.0.0", only: [:dev]}
    ]
  end
end
