# Panda

**TODO: Add description**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add `panda` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:panda, "~> 0.1.0"}]
    end
    ```

  2. Ensure `panda` is started before your application:

    ```elixir
    def application do
      [applications: [:panda]]
    end
    ```

  3. Ensure api key is configured in config/#{Mix.env}.api_key.exs:

    ```elixir
    use Mix.Config

    config :panda, api_key: "<YOUR PANDASCORE API KEY>"
    ```
