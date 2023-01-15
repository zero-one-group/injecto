defmodule Dummy do
  @properties %{
    binary: {:binary, required: true},
    binary_id: {:binary_id, required: true},
    boolean: {:boolean, required: true},
    float: {:float, required: true},
    id: {:id, required: true},
    integer: {:integer, required: true},
    string: {:string, required: true},
    map: {:map, required: true},
    decimal: {:decimal, required: true},
    date: {:date, required: true},
    time: {:time, required: true},
    time_usec: {:time_usec, required: true},
    naive_datetime: {:naive_datetime, required: true},
    naive_datetime_usec: {:naive_datetime_usec, required: true},
    utc_datetime: {:utc_datetime, required: true},
    utc_datetime_usec: {:utc_datetime_usec, required: true},
    array_integer: {{:array, :integer}, required: true},
    array_string: {{:array, :string}, required: true},
    enum_abc: {{:enum, [:a, :b, :c]}, required: true},
    enum_123: {{:enum, [a: 1, b: 2, c: 3]}, required: true},
    array_enum_abc: {{:array, {:enum, [:a, :b, :c]}}, required: true},
    array_enum_123: {{:array, {:enum, [a: 1, b: 2, c: 3]}}, required: true}
  }
  use Injecto
end

defmodule OptionalDummy do
  @properties %{
    required: {:integer, required: true},
    optional: {:integer, required: false}
  }
  use Injecto
end

defmodule PointDummy do
  @properties %{
    x: {:integer, required: true},
    y: {:integer, required: false}
  }
  use Injecto
end

defmodule KeywordDummy do
  @properties %{
    int_min: {:integer, minimum: 0},
    int_exc_min: {:integer, exclusive_minimum: 0},
    int_max: {:integer, maximum: 0},
    int_exc_max: {:integer, exclusive_maximum: 0},
    str_min: {:string, min_length: 1},
    str_max: {:string, max_length: 1},
    phone: {:string, pattern: "^(\\([0-9]{3}\\))?[0-9]{3}-[0-9]{4}$"},
    email: {:string, format: "email"},
    arr_min: {{:array, :integer}, min_items: 1},
    arr_max: {{:array, :integer}, max_items: 1},
    arr_unique: {{:array, :integer}, unique_items: true}
  }
  use Injecto
end

defmodule ParentDummy do
  @properties %{
    scalar: {:string, required: true},
    embed_one: {{:object, __MODULE__.ChildDummy}, required: true},
    embed_many: {{:array, __MODULE__.ChildDummy}, required: true}
  }
  use Injecto

  defmodule ChildDummy do
    @properties %{
      x: {:integer, required: true},
      y: {:integer, required: true},
      z: {:integer, required: true}
    }
    use Injecto
  end
end
