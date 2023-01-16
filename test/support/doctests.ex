defmodule Post do
  @properties %{
    title: {:string, required: true},
    description: {:string, []},
    likes: {:integer, required: true, minimum: 0}
  }
  use Injecto
end
