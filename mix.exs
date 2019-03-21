defmodule Rservex.MixProject do
  use Mix.Project

  def project do
    [
      app: :rservex,
      version: "0.1.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package()
    ]
  end

  defp description() do
    "Rservex is an under-development client for Rserve. Aiming to enable the R <--> Elixir interoperation."
  end

  defp package do
    [
      name: "rservex",
      maintainers: ["Julian Otalvaro"],
      licenses: ["Apache 2.0"],
      links: %{github: "https://github.com/siel/rservex"}
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end
end
