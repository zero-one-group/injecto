defmodule Injecto do
  @callback new() :: struct()
  @callback changeset(struct(), map()) :: %Ecto.Changeset{}

  defmacro __using__(_opts) do
    quote do
      @derive {Jason.Encoder, only: Map.keys(@properties)}
      @behaviour Injecto

      @example_definition """
      Given the following definition:

          defmodule Post do
            @properties %{
              title: {:string, required: true},
              description: {:string, []},
              likes: {:integer, required: true, minimum: 0}
            }
            use Injecto
          end
      """

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

      @primary_key false
      embedded_schema do
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

      @doc """
      #{@example_definition}

      Returns the struct with the fields populated with `nil`s:

          iex> Post.new()
          %Post{title: nil, description: nil, likes: nil}
      """
      @spec new() :: %__MODULE__{}
      def new, do: %__MODULE__{}

      @doc """
          iex> with %Ecto.Changeset{} = #{__MODULE__}.changeset(%#{__MODULE__}{}, %{}), do: :ok
          :ok
      """

      @doc """
      #{@example_definition}

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

      @doc """
      #{@example_definition}

      Returns an Ecto changeset:

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
      @type result :: {:ok, %__MODULE__{}} | {:error, any()}
      @spec parse(map(), Keyword.t()) :: result()
      def parse(input, opts \\ []) do
        validate_fn =
          if Keyword.get(opts, :validate_json),
            do: &validate_json/1,
            else: fn input -> {:ok, input} end

        with {:ok, _} <- validate_fn.(input) do
          parse_ecto(input)
        end
      end

      @spec parse_ecto(map()) :: result()
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

      @doc """
      #{@example_definition}

      Invokes `parse/2` on a collection of maps, and returns `:ok` if all maps can be
      correctly parsed:

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

      ## ---------------------------------------------------------------------------
      ## JSON Schema
      ## ---------------------------------------------------------------------------
      @doc """
      #{@example_definition}

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
            "x-struct" => Post
          }
      """
      @spec json_schema() :: map()
      def json_schema() do
        %{
          "type" => "object",
          "properties" => json_schema_properties(properties()),
          "required" => required_fields(properties()) |> Enum.map(&Atom.to_string/1),
          "title" => Atom.to_string(__MODULE__),
          "x-struct" => __MODULE__
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

      @doc """
      #{@example_definition}

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
