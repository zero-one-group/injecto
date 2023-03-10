defmodule InjectoTest do
  use ExUnit.Case
  doctest Injecto

  test "json_schema" do
    assert %{
             "properties" => %{
               "x" => %{"type" => "integer"},
               "y" => %{"type" => "integer"},
               "z" => %{"type" => "integer"}
             },
             "required" => ["x", "y", "z"],
             "title" => "Elixir.ParentDummy.ChildDummy",
             "type" => "object",
             "x-struct" => "Elixir.ParentDummy.ChildDummy"
           } = ParentDummy.ChildDummy.json_schema().schema
  end

  test "basic struct with all Ecto types" do
    valid_map = %{
      binary: "xyz",
      binary_id: "1",
      boolean: true,
      float: 1.0,
      id: 1,
      integer: 1,
      string: "abc",
      map: %{a: 1},
      decimal: Decimal.new(1),
      date: Date.utc_today(),
      time: Time.utc_now(),
      time_usec: Time.utc_now(),
      naive_datetime: NaiveDateTime.utc_now(),
      naive_datetime_usec: NaiveDateTime.utc_now(),
      utc_datetime: DateTime.utc_now(),
      utc_datetime_usec: DateTime.utc_now(),
      array_integer: [1, 2, 3],
      array_string: ["ABC", "DEF"],
      enum_abc: :b,
      enum_123: 1,
      array_enum_abc: [:a, :b, :c],
      array_enum_123: [1, 2, 3]
    }

    assert {:ok, %Dummy{}} = Dummy.parse(valid_map)
    assert {:ok, _} = Dummy.validate_json(valid_map)

    invalid_pairs = [
      {:binary, 123},
      {:binary_id, 1},
      {:boolean, 1},
      {:float, "ghi"},
      {:id, "abc"},
      {:integer, "def"},
      {:string, 123},
      {:map, "[]"},
      {:decimal, %{}},
      {:date, 1},
      {:date, "ghi"},
      {:time, 1},
      {:time, "jkl"},
      {:time_usec, 1},
      {:time_usec, "mno"},
      {:naive_datetime, :ghi},
      {:naive_datetime_usec, :jkl},
      {:utc_datetime, :mno},
      {:utc_datetime_usec, :pqr},
      {:array_integer, ["ABC", "DEF"]},
      {:array_string, [1, 2, 3]},
      {:enum_abc, :d},
      {:enum_123, 4},
      {:array_enum_abc, [:b, :c, :d]},
      {:array_enum_123, [2, 3, 4]}
    ]

    for {key, value} <- invalid_pairs do
      invalid_map = Map.put(valid_map, key, value)
      assert {:error, _} = Dummy.parse(invalid_map)
      assert {:error, _} = Dummy.validate_json(invalid_map)
    end
  end

  test "field optionality" do
    for valid_map <- [
          %{required: 1, optional: 1},
          %{required: 1, optional: nil},
          %{required: 1}
        ] do
      assert {:ok, %OptionalDummy{}} = OptionalDummy.parse(valid_map)
      assert {:ok, _} = OptionalDummy.validate_json(valid_map)
    end

    for invalid_map <- [
          %{required: nil},
          %{required: nil, optional: 1},
          %{optional: 1},
          %{optional: nil},
          %{}
        ] do
      assert {:error, _} = OptionalDummy.parse(invalid_map)
      assert {:error, _} = OptionalDummy.validate_json(invalid_map)
    end
  end

  test "parse_many" do
    valid_maps = [
      %{x: 0, y: 0},
      %{x: 0, y: nil},
      %{x: 0}
    ]

    assert {:ok, [%PointDummy{} | _]} = PointDummy.parse_many(valid_maps)

    invalid_maps = [
      %{x: nil},
      %{equired: nil, y: 1},
      %{y: 1},
      %{y: nil},
      %{}
    ]

    assert {:error, _} = PointDummy.parse_many(invalid_maps)
    assert {:error, _} = PointDummy.parse_many(valid_maps ++ invalid_maps)

    for invalid_map <- invalid_maps do
      assert {:error, _} = PointDummy.parse_many(valid_maps ++ [invalid_map])
    end
  end

  test "JSON schema extra keywords" do
    valid_maps = [
      %{int_min: 0},
      %{int_exc_min: 1},
      %{int_max: 0},
      %{int_exc_max: -1},
      %{str_min: "a"},
      %{str_max: "a"},
      %{phone: "(888)555-1212"},
      %{email: "abc@def.com"},
      %{arr_min: [0]},
      %{arr_max: [0]},
      %{arr_unique: [0]}
    ]

    for valid_map <- valid_maps do
      assert {:ok, %KeywordDummy{}} = KeywordDummy.parse(valid_map)
      assert {:ok, _} = KeywordDummy.validate_json(valid_map)
    end

    invalid_maps = [
      %{int_min: -1},
      %{int_exc_min: 0},
      %{int_max: 1},
      %{int_exc_max: 0},
      %{str_min: ""},
      %{str_max: "ab"},
      %{phone: "(800)FLOWERS"},
      %{email: "abc@def"},
      %{arr_min: []},
      %{arr_max: [0, 1]},
      %{arr_unique: [0, 0]}
    ]

    for invalid_map <- invalid_maps do
      assert {:ok, %KeywordDummy{}} = KeywordDummy.parse(invalid_map)
      assert {:error, _} = KeywordDummy.validate_json(invalid_map)
    end
  end

  test "embedded schemas" do
    valid_map = %{
      scalar: "abc",
      embed_one: %{x: 0, y: 0, z: 0},
      embed_many: 1..10 |> Enum.map(fn i -> %{x: i, y: i, z: i} end)
    }

    assert {:ok, %ParentDummy{} = parent} = ParentDummy.parse(valid_map)
    assert %ParentDummy.ChildDummy{} = parent.embed_one
    assert [%ParentDummy.ChildDummy{} | _] = parent.embed_many
    assert {:ok, _} = ParentDummy.validate_json(valid_map)

    invalid_maps = [
      %{valid_map | scalar: 1},
      %{valid_map | embed_one: %{}},
      %{valid_map | embed_many: [%{}]},
      %{valid_map | embed_many: ["abc"]}
    ]

    for invalid_map <- invalid_maps do
      assert {:error, _} = ParentDummy.parse(invalid_map)
      assert {:error, _} = ParentDummy.validate_json(invalid_map)
    end

    invalid_json = %{valid_map | embed_one: %{x: 0, y: 0, z: 0, extra: 0}}
    assert {:ok, _} = ParentDummy.parse(invalid_json)
    assert {:error, _} = ParentDummy.validate_json(invalid_json)
  end

  test "idempotent parse/1 and parse_many/1" do
    map = %{x: 1, y: 1}

    for validate_json <- [false, true] do
      assert {:ok, parsed} = PointDummy.parse(map, validate_json: validate_json)
      assert {:ok, _} = PointDummy.parse(parsed, validate_json: validate_json)

      assert {:ok, parsed} = PointDummy.parse_many([map], validate_json: validate_json)
      assert {:ok, _} = PointDummy.parse_many(parsed, validate_json: validate_json)
    end

    valid_map = %{
      scalar: "abc",
      embed_one: %{x: 0, y: 0, z: 0},
      embed_many: 1..10 |> Enum.map(fn i -> %{x: i, y: i, z: i} end)
    }

    assert {:ok, parsed} = ParentDummy.parse(valid_map)
    assert {:ok, _} = ParentDummy.parse(parsed)

    assert {:ok, parsed} = ParentDummy.parse_many([valid_map])
    assert {:ok, _} = ParentDummy.parse_many(parsed)
  end

  test "Ecto schema source" do
    assert Dummy.__schema__(:source) == ""

    assert {:ok, parsed} = DummyWithSource.parse(%{id: 1})
    assert {:error, _} = DummyWithSource.parse(%{id: nil})
    assert DummyWithSource.__schema__(:source) == "dummies"
    assert Ecto.get_meta(parsed, :source) == "dummies"
  end
end
