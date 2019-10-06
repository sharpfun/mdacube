defmodule MdacubeTest do
  use ExUnit.Case
  doctest MDACube

  test "empty cube" do
    assert MDACube.count(MDACube.new()) == 0
  end
end
