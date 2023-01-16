# Injecto

A behaviour module that defines both an Ecto schema and a JSON schema.

An Injecto schema uses the module attribute `@properties` to define an Ecto schema and
a JSON schema based on the `ex_json_schema` library. In doing so, it also injects a
`Jason` encoder implementation. The advantage of using an Injecto schema is to get a
consistent parsing and validating with Ecto changesets and JSON schema respectively
with minimal boilerplates. This consistency is helpful when working with struct-based
request or response bodies, because we can get accurate Swagger schemas for free.

Example:

```elixir
defmodule Post do
  @properties %{
    title: {:string, required: true},
    description: {:string, []},
    likes: {:integer, required: true, minimum: 0}
  }
  use Injecto
end
```

Refer to the [Injecto HexDocs](https://hexdocs.pm/injecto) for a more information.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `injecto` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:injecto, "~> 0.1.0"}
  ]
end
```
