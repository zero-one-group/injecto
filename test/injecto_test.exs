defmodule InjectoTest do
  use ExUnit.Case
  doctest Injecto

  test "greets the world" do
    assert Injecto.hello() == :world
  end
end
