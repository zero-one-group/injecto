defmodule Injecto do
  @callback new() :: struct()
  @callback changeset(struct(), map()) :: %Ecto.Changeset{}

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

      # TODO: support for non-embedded schemas
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

      @spec new() :: %__MODULE__{}
      def new, do: %__MODULE__{}

      @spec changeset(struct(), map()) :: %Ecto.Changeset{}
      def changeset(struct, map), do: base_changeset(struct, map)
      defoverridable changeset: 2

      @spec base_changeset(struct(), map()) :: %Ecto.Changeset{}
      def base_changeset(struct, map) do
        init_changeset =
          struct
          |> cast(map, all_non_embeds())
          |> validate_required(required_non_embeds())

        embedded_properties = Enum.filter(properties(), &embedded?/1)

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
      @spec parse(map()) :: result()
      def parse(input) do
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
      @spec parse_many([map()]) :: results()
      def parse_many(inputs) do
        reduced =
          Enum.reduce(
            inputs,
            %{oks: [], errors: []},
            fn input, acc ->
              case parse(input) do
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
      # TODO: support for other JSON schema options
      @type_map %{
        binary: %{"type" => "string"},
        binary_id: %{"type" => "string"},
        float: %{"type" => "number"},
        decimal: %{"type" => "string"},
        id: %{"type" => "integer"},
        map: %{"type" => "object"},
        date: %{"type" => "string", "format" => "date"},
        time: %{"type" => "string", "format" => "time"},
        time_usec: %{"type" => "string", "format" => "time"},
        naive_datetime: %{"type" => "string", "format" => "date-time"},
        naive_datetime_usec: %{"type" => "string", "format" => "date-time"},
        utc_datetime: %{"type" => "string", "format" => "date-time"},
        utc_datetime_usec: %{"type" => "string", "format" => "date-time"}
      }

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
      def json_schema_properties(props) do
        props
        |> Enum.map(fn {name, {type, opts}} ->
          name = Atom.to_string(name)

          case type do
            {:object, module} ->
              {name, module.json_schema()}

            {:array, inner_type} ->
              case inner_type do
                {:enum, values} ->
                  {name, %{"type" => "array", "items" => enum_schema(values)}}

                inner_type when inner_type in @scalar_types ->
                  {name, %{"type" => "array", "items" => %{"type" => Atom.to_string(inner_type)}}}

                _ ->
                  {name, %{"type" => "array", "items" => inner_type.json_schema()}}
              end

            {:enum, values} ->
              {name, enum_schema(values)}

            type ->
              default = %{"type" => Atom.to_string(type)}
              schema_type = Map.get(@type_map, type, default)
              {name, schema_type}
          end
        end)
        |> Enum.into(%{})
      end

      @spec enum_schema([atom()] | Keyword.t()) :: map()
      def enum_schema(values) do
        if Keyword.keyword?(values) do
          %{"type" => "integer", "enum" => Keyword.values(values)}
        else
          %{"type" => "string", "enum" => Enum.map(values, &Atom.to_string/1)}
        end
      end

      @spec json_schema_validate(map()) :: {:ok, map()} | {:error, any()}
      def json_schema_validate(map) do
        with {:ok, encoded} <- Jason.encode(map),
             {:ok, json} <- Jason.decode(encoded),
             :ok <- ExJsonSchema.Validator.validate(json_schema(), json) do
          {:ok, map}
        end
      end

      ## ---------------------------------------------------------------------------
      ## Utilities
      ## ---------------------------------------------------------------------------
      @spec properties() :: map()
      def properties(), do: @properties

      @spec all_fields() :: [atom()]
      def all_fields(), do: all_fields(properties())

      @spec all_fields(map()) :: [atom()]
      def all_fields(props) do
        props
        |> Enum.map(fn {name, _} -> name end)
      end

      @spec all_non_embeds() :: [atom()]
      def all_non_embeds(), do: all_non_embeds(properties())

      @spec all_non_embeds(map()) :: [atom()]
      def all_non_embeds(props) do
        props
        |> Enum.filter(fn {_name, {type, _opts}} -> !embedded?(type) end)
        |> Enum.map(fn {name, _} -> name end)
      end

      @spec optional_fields() :: [atom()]
      def optional_fields(), do: optional_fields(properties())

      @spec optional_fields(map()) :: [atom()]
      def optional_fields(props) do
        props
        |> Enum.filter(fn {_name, {_type, opts}} ->
          !Keyword.get(opts, :required, false)
        end)
        |> Enum.map(fn {name, _} -> name end)
      end

      @spec required_fields() :: [atom()]
      def required_fields(), do: required_fields(properties())

      @spec required_fields(map()) :: [atom()]
      def required_fields(props) do
        props
        |> Enum.filter(fn {_name, {_type, opts}} ->
          Keyword.get(opts, :required, false)
        end)
        |> Enum.map(fn {name, _} -> name end)
      end

      @spec required_non_embeds() :: [atom()]
      def required_non_embeds(), do: required_non_embeds(properties())

      @spec required_non_embeds(map()) :: [atom()]
      def required_non_embeds(props) do
        props
        |> Enum.filter(fn {_name, {type, _opts}} -> !embedded?(type) end)
        |> Enum.filter(fn {_name, {_type, opts}} ->
          Keyword.get(opts, :required, false)
        end)
        |> Enum.map(fn {name, _} -> name end)
      end

      def embedded?(type) do
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

    # TODO: add .generate(opts \\ []) function
  end
end
