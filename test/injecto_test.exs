defmodule InjectoTest do
  use ExUnit.Case
  doctest Injecto

  test "basic struct with scalar Ecto types" do
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
      utc_datetime_usec: DateTime.utc_now()
    }

    assert {:ok, %Dummy{}} = Dummy.parse(valid_map)
    assert {:ok, _} = Dummy.json_schema_validate(valid_map)

    # TODO: test for castable pairs

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
      {:utc_datetime_usec, :pqr}
    ]

    for {key, value} <- invalid_pairs do
      {key, value} |> IO.inspect()
      invalid_map = Map.put(valid_map, key, value)
      assert {:error, _} = Dummy.parse(invalid_map)
      assert {:error, _} = Dummy.json_schema_validate(invalid_map)
    end
  end

  # TODO: test for optionality
end
