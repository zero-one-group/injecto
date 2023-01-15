defmodule InjectoTest do
  use ExUnit.Case
  doctest Injecto

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
    assert {:error, _} = PointDummy.parse_many(valid_maps ++ Enum.take(invalid_maps, 1))
  end

  # TODO: test JSON schema options
end
