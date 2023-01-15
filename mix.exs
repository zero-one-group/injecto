defmodule Injecto.MixProject do
  use Mix.Project

  def project do
    [
      app: :injecto,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:ecto_sql, "~> 3.6"},
      {:ex_json_schema, "~> 0.9.2"},
      {:jason, "~> 1.4"},
      {:decimal, "~> 2.0"}
    ]
  end
end
