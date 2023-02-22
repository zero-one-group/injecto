defmodule Injecto do
  @moduledoc """
  A behaviour module that defines both an Ecto schema and a JSON schema.

  An Injecto schema uses the module attribute `@properties` to define an Ecto schema and
  a JSON schema based on the `ex_json_schema` library. In doing so, it also injects a
  `Jason` encoder implementation. The advantage of using an Injecto schema is to get a
  consistent parsing and validating with Ecto changesets and JSON schema respectively
  with minimal boilerplates. This consistency is helpful when working with struct-based
  request or response bodies, because we can get accurate Swagger schemas for free.

  ## Example

  In the following documentation, we will use this simple Injecto schema as example:

      defmodule Post do
        @properties %{
          title: {:string, required: true},
          description: {:string, []},
          likes: {:integer, required: true, minimum: 0}
        }
        use Injecto
      end

  The module attribute `@properties` must be defined first before invoking `use Injecto`.
  The properties attribute is a map with field names as keys and field specs as values.
  A field spec is a 2-tuple of `{type, options}`. For scalar types, most Ecto field types
  are supported, namely:

      [
        :binary,
        :binary_id,
        :boolean,
        :float,
        :id,
        :integer,
        :string,
        :map,
        :decimal,
        :date,
        :time,
        :time_usec,
        :naive_datetime,
        :naive_datetime_usec,
        :utc_datetime,
        :utc_datetime_usec
      ]

  Refer to Ecto's documentation on
  [Primitive Types](https://hexdocs.pm/ecto/Ecto.Schema.html#module-primitive-types)
  to see how these field types get translated into Elixir types.

  Supported compound types include:

    * `{:enum, atoms}` and `{:enum, keyword}`;
    * `{:object, injecto_module}`; and
    * `{:array, inner_type}` where `inner_type` can be a scalar, enum or object type.

  ## Usage: Ecto

  On the Ecto side, `new/0` and `changeset/2` functions can create a `nil`-filled struct
  and an Ecto changeset respectively.

      iex> Post.new()
      %Post{title: nil, description: nil, likes: nil}

      iex> %Ecto.Changeset{valid?: false, errors: errors} = Post.changeset(%Post{}, %{})
      iex> errors
      [
        likes: {"can't be blank", [validation: :required]},
        title: {"can't be blank", [validation: :required]}
      ]

      iex> post = %{title: "Valid", likes: 10}
      iex> %Ecto.Changeset{valid?: true, errors: []} = Post.changeset(%Post{}, post)

  The `parse/2` function convert a map to a changeset-validated struct.

      iex> {:error, errors} = Post.parse(%{})
      iex> errors
      %{
        likes: [{"can't be blank", [validation: :required]}],
        title: [{"can't be blank", [validation: :required]}]
      }

      iex> post = %{title: "Valid", likes: 10}
      iex> {:ok, %Post{title: "Valid", likes: 10}} = Post.parse(post)

      iex> valid_posts = [%{title: "A", likes: 1}, %{title: "B", likes: 2}]
      iex> {:ok, posts} = Post.parse_many(valid_posts)
      iex> Enum.sort_by(posts, &(&1.title))
      [
        %Post{title: "A", likes: 1, description: nil},
        %Post{title: "B", likes: 2, description: nil}
      ]

  The `parse_many/2` function is the collection counter part of `parse/2`. One validation
  error is considered to be an error for the entire collection:

      iex> invalid_posts = [%{title: 1, likes: "A"}, %{title: 2, likes: "B"}]
      iex> {:error, errors} = Post.parse_many(invalid_posts)
      iex> errors
      [
        %{
          likes: [{"is invalid", [type: :integer, validation: :cast]}],
          title: [{"is invalid", [type: :string, validation: :cast]}]
        },
        %{
          likes: [{"is invalid", [type: :integer, validation: :cast]}],
          title: [{"is invalid", [type: :string, validation: :cast]}]
        }
      ]

      iex> valid_posts = [%{title: "A", likes: 1}, %{title: "B", likes: 2}]
      iex> invalid_posts = [%{title: 1, likes: "A"}]
      iex> {:error, errors} = Post.parse_many(valid_posts ++ invalid_posts)
      iex> errors
      [
        %{
          likes: [{"is invalid", [type: :integer, validation: :cast]}],
          title: [{"is invalid", [type: :string, validation: :cast]}]
        }
      ]

  Note that JSON schema constraints such as `minimum: 0` are not caught by the Ecto changeset:

      iex> post = %{title: "Invalid", likes: -1}
      iex> %Ecto.Changeset{valid?: true, errors: []} = Post.changeset(%Post{}, post)

  ## Usage: JSON Schema

  The function `json_schema/0` returns a resolved `ExJsonSchema.Scheam.Root` struct.

      iex> %ExJsonSchema.Schema.Root{schema: schema} = Post.json_schema()
      iex> schema
      %{
        "properties" => %{
          "description" => %{
            "anyOf" => [%{"type" => "string"}, %{"type" => "null"}]
          },
          "likes" => %{"minimum" => 0, "type" => "integer"},
          "title" => %{"type" => "string"}
        },
        "required" => ["likes", "title"],
        "title" => "Elixir.Post",
        "type" => "object",
        "x-struct" => "Elixir.Post"
      }


  Internally, this is used by `validate_json/1` to validate a map using the JSON schema.

      iex> valid_post = %{title: "A", likes: 1}
      iex> {:ok, ^valid_post} = Post.validate_json(valid_post)

      iex> invalid_post = %{title: 123, likes: -1}
      iex> {:error, errors} = Post.validate_json(invalid_post)
      iex> Enum.sort(errors)
      [
        {"Expected the value to be >= 0", "#/likes"},
        {"Type mismatch. Expected String but got Integer.", "#/title"}
      ]
  """

  @doc """
  Returns the struct with the fields populated with `nil`s:

      iex> Post.new()
      %Post{title: nil, description: nil, likes: nil}
  """
  @callback new() :: struct()

  @doc """
  Returns an Ecto changeset:

      iex> %Ecto.Changeset{valid?: false, errors: errors} = Post.changeset(%Post{}, %{})
      iex> errors
      [
        likes: {"can't be blank", [validation: :required]},
        title: {"can't be blank", [validation: :required]}
      ]

      iex> post = %{title: "Valid", likes: 10}
      iex> %Ecto.Changeset{valid?: true, errors: []} = Post.changeset(%Post{}, post)

  Note that JSON schema constraints such as `minimum: 0` are not caught by the Ecto changeset:

      iex> post = %{title: "Invalid", likes: -1}
      iex> %Ecto.Changeset{valid?: true, errors: []} = Post.changeset(%Post{}, post)
  """
  @callback changeset(struct(), map()) :: %Ecto.Changeset{}

  @doc """
  Returns a result of a validated Elixir struct or the validation errors:

      iex> {:error, errors} = Post.parse(%{})
      iex> errors
      %{
        likes: [{"can't be blank", [validation: :required]}],
        title: [{"can't be blank", [validation: :required]}]
      }

      iex> post = %{title: "Valid", likes: 10}
      iex> {:ok, %Post{title: "Valid", likes: 10}} = Post.parse(post)

  Note that JSON schema constraints such as `minimum: 0` are not caught by `parse/2` by
  default. Pass in the option `:validate_json` for JSON schema validation:

      iex> post = %{title: "Invalid", likes: -1}
      iex> {:ok, %Post{}} = Post.parse(post)

      iex> post = %{title: "Invalid", likes: -1}
      iex> {:error, errors} = Post.parse(post, validate_json: true)
      iex> errors
      [{"Expected the value to be >= 0", "#/likes"}]
  """
  @callback parse(map(), Keyword.t()) :: {:ok, struct()} | {:error, any()}

  @doc """
  Calls `parse/2` on a list of maps. Returns `:ok` if all maps are parsed correctly.

      iex> valid_posts = [%{title: "A", likes: 1}, %{title: "B", likes: 2}]
      iex> {:ok, posts} = Post.parse_many(valid_posts)
      iex> Enum.sort_by(posts, &(&1.title))
      [
        %Post{title: "A", likes: 1, description: nil},
        %Post{title: "B", likes: 2, description: nil}
      ]

      iex> invalid_posts = [%{title: 1, likes: "A"}, %{title: 2, likes: "B"}]
      iex> {:error, errors} = Post.parse_many(invalid_posts)
      iex> errors
      [
        %{
          likes: [{"is invalid", [type: :integer, validation: :cast]}],
          title: [{"is invalid", [type: :string, validation: :cast]}]
        },
        %{
          likes: [{"is invalid", [type: :integer, validation: :cast]}],
          title: [{"is invalid", [type: :string, validation: :cast]}]
        }
      ]

      iex> valid_posts = [%{title: "A", likes: 1}, %{title: "B", likes: 2}]
      iex> invalid_posts = [%{title: 1, likes: "A"}]
      iex> {:error, errors} = Post.parse_many(valid_posts ++ invalid_posts)
      iex> errors
      [
        %{
          likes: [{"is invalid", [type: :integer, validation: :cast]}],
          title: [{"is invalid", [type: :string, validation: :cast]}]
        }
      ]

  Note that JSON schema constraints such as `minimum: 0` are not caught by `parse` by
  default. Pass in the option `:validate_json` for JSON schema validation:

      iex> posts = [%{title: "A", likes: -1}]
      iex> {:ok, _} = Post.parse_many(posts)
      iex> {:error, errors} = Post.parse_many(posts, validate_json: true)
      iex> errors
      [[{"Expected the value to be >= 0", "#/likes"}]]
  """
  @callback parse_many([map()], Keyword.t()) :: {:ok, [struct()]} | {:error, any()}

  @doc """
  Validates and returns an `ex_json_schema` schema:

      iex> %ExJsonSchema.Schema.Root{schema: schema} = Post.json_schema()
      iex> schema
      %{
        "properties" => %{
          "description" => %{
            "anyOf" => [%{"type" => "string"}, %{"type" => "null"}]
          },
          "likes" => %{"minimum" => 0, "type" => "integer"},
          "title" => %{"type" => "string"}
        },
        "required" => ["likes", "title"],
        "title" => "Elixir.Post",
        "type" => "object",
        "x-struct" => "Elixir.Post"
      }
  """
  @callback json_schema() :: %ExJsonSchema.Schema.Root{}

  @doc """
  Serialises a map, and validates the deserialised result against the JSON schema:

      iex> valid_post = %{title: "A", likes: 1}
      iex> {:ok, ^valid_post} = Post.validate_json(valid_post)

      iex> invalid_post = %{title: 123, likes: -1}
      iex> {:error, errors} = Post.validate_json(invalid_post)
      iex> Enum.sort(errors)
      [
        {"Expected the value to be >= 0", "#/likes"},
        {"Type mismatch. Expected String but got Integer.", "#/title"}
      ]

  """
  @callback validate_json(map()) :: {:ok, map()} | {:error, any()}

  defmacro __using__(_opts) do
    quote do
      @derive {Jason.Encoder, only: Map.keys(@properties)}
      @behaviour Injecto

      @scalar_types [
        :binary,
        :binary_id,
        :boolean,
        :float,
        :id,
        :integer,
        :string,
        :map,
        :decimal,
        :date,
        :time,
        :time_usec,
        :naive_datetime,
        :naive_datetime_usec,
        :utc_datetime,
        :utc_datetime_usec
      ]

      ## ---------------------------------------------------------------------------
      ## Ecto
      ## ---------------------------------------------------------------------------
      use Ecto.Schema
      import Ecto.Changeset

      Module.register_attribute(__MODULE__, :source, [])

      @source @source || ""

      @primary_key false
      schema @source do
        @properties
        |> Enum.map(fn {name, {type, _opts}} ->
          case type do
            {:object, module} ->
              embeds_one(name, module)

            {:array, inner_type} ->
              case inner_type do
                {:enum, values} ->
                  field(name, {:array, Ecto.Enum}, values: values)

                _ ->
                  if Enum.member?(@scalar_types, inner_type),
                    do: field(name, {:array, inner_type}),
                    else: embeds_many(name, inner_type)
              end

            {:enum, values} ->
              field(name, Ecto.Enum, values: values)

            type ->
              field(name, type)
          end
        end)
      end

      @spec new() :: %__MODULE__{}
      def new, do: %__MODULE__{}

      @spec changeset(struct(), map()) :: %Ecto.Changeset{}
      def changeset(struct, map), do: base_changeset(struct, map)
      defoverridable changeset: 2

      @spec base_changeset(struct(), map()) :: %Ecto.Changeset{}
      defp base_changeset(struct, map) do
        init_changeset =
          struct
          |> cast(map, all_non_embeds())
          |> validate_required(required_non_embeds())

        embedded_properties =
          Enum.filter(properties(), fn {_name, {type, _opt}} -> embedded?(type) end)

        Enum.reduce(
          embedded_properties,
          init_changeset,
          fn {name, {_type, opts}}, acc_changeset ->
            required? = Keyword.get(opts, :required, false)
            acc_changeset |> cast_embed(name, required: required?)
          end
        )
      end

      @type result :: {:ok, %__MODULE__{}} | {:error, any()}
      @spec parse(map() | %__MODULE__{}, Keyword.t()) :: result()
      def parse(input, opts \\ []) do
        input = ensure_nested_map(input)

        validate_fn =
          if Keyword.get(opts, :validate_json),
            do: &validate_json/1,
            else: fn input -> {:ok, input} end

        with {:ok, _} <- validate_fn.(input) do
          parse_ecto(input)
        end
      end

      @spec parse_ecto(map() | %__MODULE__{}) :: result()
      defp parse_ecto(input) do
        changeset = __MODULE__.changeset(__MODULE__.new(), input)

        if changeset.valid? do
          {:ok, Ecto.Changeset.apply_changes(changeset)}
        else
          errors =
            changeset
            |> Ecto.Changeset.traverse_errors(&Function.identity/1)

          {:error, errors}
        end
      end

      @type results :: {:ok, [%__MODULE__{}]} | {:error, any()}
      @spec parse_many([map()], Keyword.t()) :: results()
      def parse_many(inputs, opts \\ []) do
        reduced =
          Enum.reduce(
            inputs,
            %{oks: [], errors: []},
            fn input, acc ->
              case parse(input, opts) do
                {:ok, ok} -> %{acc | oks: [ok | acc[:oks]]}
                {:error, error} -> %{acc | errors: [error | acc[:errors]]}
              end
            end
          )

        case reduced do
          %{errors: [], oks: oks} -> {:ok, oks}
          %{errors: errors} -> {:error, errors}
        end
      end

      # Source: https://elixirforum.com/t/convert-a-nested-struct-into-a-nested-map/23814/7
      @spec ensure_nested_map(map() | struct()) :: map()
      @guarded_structs [Date, DateTime, NaiveDateTime, Time, Decimal]
      defp ensure_nested_map(%{__struct__: struct} = data) when struct in @guarded_structs,
        do: data

      defp ensure_nested_map(struct) when is_struct(struct) do
        map = Map.from_struct(struct)
        :maps.map(fn _, value -> ensure_nested_map(value) end, map)
      end

      defp ensure_nested_map(map) when is_map(map),
        do: :maps.map(fn _, value -> ensure_nested_map(value) end, map)

      defp ensure_nested_map(list) when is_list(list),
        do: Enum.map(list, &ensure_nested_map/1)

      defp ensure_nested_map(data), do: data

      ## ---------------------------------------------------------------------------
      ## JSON Schema
      ## ---------------------------------------------------------------------------
      @spec json_schema() :: %ExJsonSchema.Schema.Root{}
      def json_schema() do
        %{
          "type" => "object",
          "properties" => json_schema_properties(properties()),
          "required" => required_fields(properties()) |> Enum.map(&Atom.to_string/1),
          "title" => Atom.to_string(__MODULE__),
          "x-struct" => Atom.to_string(__MODULE__)
        }
        |> ExJsonSchema.Schema.resolve()
      end

      @spec json_schema_properties(map()) :: map()
      defp json_schema_properties(props) do
        props
        |> Enum.map(fn {name, {type, opts}} ->
          schema =
            case type do
              {:object, module} -> Map.merge(object_schema(opts), module.json_schema().schema)
              {:array, inner_type} -> array_schema({:array, inner_type}, opts)
              {:enum, values} -> enum_schema({:enum, values}, opts)
              type -> scalar_schema(type, opts)
            end

          schema =
            if Keyword.get(opts, :required),
              do: schema,
              else: %{"anyOf" => [schema, %{"type" => "null"}]}

          {Atom.to_string(name), schema}
        end)
        |> Enum.into(%{})
      end

      @spec array_schema({atom(), any()}, Keyword.t()) :: map()
      defp array_schema({:array, inner_type}, opts) do
        schema =
          case inner_type do
            {:enum, values} ->
              %{"type" => "array", "items" => enum_schema({:enum, values}, [])}

            inner_type when inner_type in @scalar_types ->
              %{"type" => "array", "items" => %{"type" => Atom.to_string(inner_type)}}

            _ ->
              %{"type" => "array", "items" => inner_type.json_schema().schema}
          end

        opts =
          opts
          |> Keyword.take([:min_items, :max_items, :unique_items])
          |> Enum.map(fn {key, value} ->
            case key do
              :min_items -> {"minItems", value}
              :max_items -> {"maxItems", value}
              :unique_items -> {"uniqueItems", value}
              _ -> {Atom.to_string(key), value}
            end
          end)
          |> Enum.into(%{})

        Map.merge(schema, opts)
      end

      @spec enum_schema({:enum, [atom()] | Keyword.t()}, Keyword.t()) :: map()
      defp enum_schema({:enum, values}, _opts) do
        if Keyword.keyword?(values) do
          %{"type" => "integer", "enum" => Keyword.values(values)}
        else
          %{"type" => "string", "enum" => Enum.map(values, &Atom.to_string/1)}
        end
      end

      @spec scalar_schema(atom(), Keyword.t()) :: map()
      defp scalar_schema(type, opts) do
        case type do
          :binary -> string_schema(opts)
          :binary_id -> string_schema(opts)
          :float -> number_schema(opts)
          :id -> integer_schema(opts)
          :integer -> integer_schema(opts)
          :string -> string_schema(opts)
          :map -> object_schema(opts)
          :decimal -> string_schema(opts)
          :date -> string_schema(Keyword.put(opts, :format, "date"))
          :time -> string_schema(Keyword.put(opts, :format, "time"))
          :time_usec -> string_schema(Keyword.put(opts, :format, "time"))
          :naive_datetime -> string_schema(Keyword.put(opts, :format, "date-time"))
          :naive_datetime_usec -> string_schema(Keyword.put(opts, :format, "date-time"))
          :utc_datetime -> string_schema(Keyword.put(opts, :format, "date-time"))
          :utc_datetime_usec -> string_schema(Keyword.put(opts, :format, "date-time"))
          type -> %{"type" => Atom.to_string(type)}
        end
      end

      @spec string_schema(Keyword.t()) :: map()
      defp string_schema(opts) do
        opts =
          opts
          |> Keyword.take([:format, :min_length, :max_length, :pattern])
          |> Enum.map(fn {key, value} ->
            case key do
              :min_length -> {"minLength", value}
              :max_length -> {"maxLength", value}
              _ -> {Atom.to_string(key), value}
            end
          end)
          |> Enum.into(%{})

        Map.put(opts, "type", "string")
      end

      @spec object_schema(Keyword.t()) :: map()
      defp object_schema(opts) do
        opts =
          opts
          |> Keyword.take([
            :additional_properties,
            :property_names,
            :min_properties,
            :max_properties
          ])
          |> Enum.map(fn {key, value} ->
            case key do
              :additional_properties -> {"additionalProperties", value}
              :property_names -> {"propertyNames", value}
              :min_properties -> {"minProperties", value}
              :max_properties -> {"maxProperties", value}
              _ -> {Atom.to_string(key), value}
            end
          end)
          |> Enum.into(%{})

        Map.put(opts, "type", "object")
      end

      @spec integer_schema(Keyword.t()) :: map()
      defp integer_schema(opts) do
        %{number_schema(opts) | "type" => "integer"}
      end

      @spec number_schema(Keyword.t()) :: map()
      defp number_schema(opts) do
        opts =
          opts
          |> Keyword.take([
            :multiple_of,
            :minimum,
            :exclusive_minimum,
            :maximum,
            :exclusive_maximum
          ])
          |> Enum.map(fn {key, value} ->
            case key do
              :multiple_of -> {"multipleOf", value}
              :exclusive_minimum -> {"exclusiveMinimum", value}
              :exclusive_maximum -> {"exclusiveMaximum", value}
              _ -> {Atom.to_string(key), value}
            end
          end)
          |> Enum.into(%{})

        Map.put(opts, "type", "number")
      end

      @spec validate_json(map()) :: {:ok, map()} | {:error, any()}
      def validate_json(map) do
        with {:ok, encoded} <- Jason.encode(map),
             {:ok, json} <- Jason.decode(encoded),
             :ok <- ExJsonSchema.Validator.validate(json_schema(), json) do
          {:ok, map}
        end
      end

      ## ---------------------------------------------------------------------------
      ## Utilities
      ## ---------------------------------------------------------------------------
      @doc """
      Returns the module attribute `@properties`.

        iex> Post.properties()
        %{
          description: {:string, []},
          likes: {:integer, [required: true, minimum: 0]},
          title: {:string, [required: true]}
        }
      """
      @spec properties() :: map()
      def properties(), do: @properties

      @spec all_fields() :: [atom()]
      defp all_fields(), do: all_fields(properties())

      @spec all_fields(map()) :: [atom()]
      defp all_fields(props) do
        props
        |> Enum.map(fn {name, _} -> name end)
      end

      @spec all_non_embeds() :: [atom()]
      defp all_non_embeds(), do: all_non_embeds(properties())

      @spec all_non_embeds(map()) :: [atom()]
      defp all_non_embeds(props) do
        props
        |> Enum.filter(fn {_name, {type, _opts}} -> !embedded?(type) end)
        |> Enum.map(fn {name, _} -> name end)
      end

      @spec optional_fields() :: [atom()]
      defp optional_fields(), do: optional_fields(properties())

      @spec optional_fields(map()) :: [atom()]
      defp optional_fields(props) do
        props
        |> Enum.filter(fn {_name, {_type, opts}} ->
          !Keyword.get(opts, :required, false)
        end)
        |> Enum.map(fn {name, _} -> name end)
      end

      @spec required_fields() :: [atom()]
      defp required_fields(), do: required_fields(properties())

      @spec required_fields(map()) :: [atom()]
      defp required_fields(props) do
        props
        |> Enum.filter(fn {_name, {_type, opts}} ->
          Keyword.get(opts, :required, false)
        end)
        |> Enum.map(fn {name, _} -> name end)
      end

      @spec required_non_embeds() :: [atom()]
      defp required_non_embeds(), do: required_non_embeds(properties())

      @spec required_non_embeds(map()) :: [atom()]
      defp required_non_embeds(props) do
        props
        |> Enum.filter(fn {_name, {type, _opts}} -> !embedded?(type) end)
        |> Enum.filter(fn {_name, {_type, opts}} ->
          Keyword.get(opts, :required, false)
        end)
        |> Enum.map(fn {name, _} -> name end)
      end

      @spec embedded?(any()) :: boolean()
      defp embedded?(type) do
        case type do
          {:object, _} ->
            true

          {:array, inner_type} ->
            case inner_type do
              {:enum, values} -> false
              _ -> !Enum.member?(@scalar_types, inner_type)
            end

          {:enum, values} ->
            false

          _ ->
            false
        end
      end
    end
  end
end
