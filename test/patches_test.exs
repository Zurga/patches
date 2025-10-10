defmodule PatchesTest do
  use ExUnit.Case
  doctest Patches
  use Patches

  defmodule ReplaceModule do
    use Patches

    patch(TestModule)
    replace(TestModule, :pattern_match_map, 2, :pattern_match)
    replace(TestModule, :pattern_match_tuple, 2, :pattern_match)
    replace(TestModule, :pattern_match_list, 2, :pattern_match)

    def pattern_match(a, b) do
      {a, b}
    end

    def pattern_match_map(a, b) do
      patched(TestModule).pattern_match_map(a, b)
    end

    def pattern_match_list(a, b) do
      patched(TestModule).pattern_match_list(a, b)
    end

    def pattern_match_tuple(a, b) do
      patched(TestModule).pattern_match_tuple(a, b)
    end
  end

  describe "replace/4: normalization of arguments" do
    test "different arguments matches can be normalized" do
      assert ReplaceModule.pattern_match_map(%{a: "a"}, %{b: "b"}) == {%{a: "a"}, %{b: "b"}}

      assert ReplaceModule.pattern_match_tuple(%{a: "a"}, %{b: "b"}) ==
               {%{a: "a"}, %{b: "b"}}

      assert ReplaceModule.pattern_match_list([1], [2]) == {[1], [2]}
    end
  end

  defmodule WrapModule do
    use Patches
    patch(TestModule)
    wrap(TestModule, :pattern_match_map, 2, :wrapper)
    def wrapper({a, b, _, _, _}), do: {:wrapped, a, b}

    def run(a, b) do
      patched(TestModule).pattern_match_map(a, b)
    end
  end

  describe "wrap/4" do
    test "function can be wrapped" do
      assert WrapModule.run(%{a: "a", b: "b"}, %{c: "c"}) == {:wrapped, "a", "b"}
    end
  end
end
