defmodule Patches.MixProject do
  use Mix.Project

  @source "https://github.com/Zurga/patches"
  def project do
    [
      app: :patches,
      description: "Patch any module",
      homepage_url: @source,
      version: "0.1.1",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: [
        exclude_patterns: ["priv", ".formatter.exs"],
        maintainers: ["Jim Lemmers"],
        licenses: ["MIT"],
        links: %{
          GitHub: @source
        }
      ]
    ]
  end

  defp elixirc_paths(env) when env in ~w/test dev/a, do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
