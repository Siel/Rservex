defmodule RservexTest do
  use ExUnit.Case
  doctest Rservex

  test "greets the world" do
    assert Rservex.hello() == :world
  end
end
