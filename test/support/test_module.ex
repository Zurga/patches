defmodule TestModule do
  def pattern_match_map(%{a: a, b: b} = map, %{c: c} = other_map) do
    {a, b, c, map, other_map}
  end

  def pattern_match_map(%{b: b, c: c} = map, %{d: d} = other_map) do
    {b, c, d, map, other_map}
  end

  def pattern_match_list([a, b] = list, list2) do
    {a, b, list, list2}
  end

  def pattern_match_tuple({a, b} = tuple, tuple2) do
    {a, b, tuple, tuple2}
  end

  # def pattern_match_binary(a <> b = binary) do
  #   {a, b, binary}
  # end
end
