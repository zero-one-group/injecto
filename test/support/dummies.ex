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
    utc_datetime_usec: {:utc_datetime_usec, required: true}
  }
  use Injecto
end
