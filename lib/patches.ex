defmodule Patches do
  alias Patches.Abstract

  defmacro __using__(opts \\ []) do
    quote do
      import unquote(__MODULE__)
      Module.register_attribute(__MODULE__, :wrappers, accumulate: true)
      Module.register_attribute(__MODULE__, :replacers, accumulate: true)
      Module.register_attribute(__MODULE__, :exports, accumulate: true)
      Module.register_attribute(__MODULE__, :module_patches, accumulate: true)

      @patcher_opts unquote(Macro.escape(opts))
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(env) do
    wrappers = Module.get_attribute(env.module, :wrappers)
    replacers = Module.get_attribute(env.module, :replacers)
    exports = Module.get_attribute(env.module, :exports)
    module_patches = Module.get_attribute(env.module, :module_patches)

    _patcher_opts =
      Module.get_attribute(env.module, :patcher_opts)

    modules_and_modifications =
      [wrappers, replacers, exports]
      |> Enum.flat_map(fn rule -> Enum.map(rule, &elem(&1, 0)) end)
      |> Enum.uniq()
      |> Enum.map(fn module ->
        wrappers = Enum.filter(wrappers, &(elem(&1, 0) == module))
        replacers = Enum.filter(replacers, &(elem(&1, 0) == module))

        exports =
          Enum.filter(exports, &(elem(&1, 0) == module))
          |> Enum.map(fn {_, func, arity} -> {func, arity} end)

        {module, %{wrap: wrappers, replace: replacers, export: exports}}
      end)
      |> Enum.into(Map.from_keys(module_patches, %{}))

    namespaced_modules =
      for {module, _} <- modules_and_modifications, into: %{} do
        {module, namespace(module, env.module)}
      end

    modules_and_binary =
      for {module, modifications} <- modules_and_modifications, into: %{} do
        binary =
          abstract_code(module)
          |> wrap_function(modifications[:wrap], env.module)
          |> replace_function(modifications[:replace], env.module)
          |> export_functions(modifications[:export])
          |> Abstract.rewrite(&Map.get(namespaced_modules, &1, &1))
          |> compile()

        {module, binary}
      end

    [
      quote do
        def patched(module) do
          for {module, binary} <- unquote(Macro.escape(modules_and_binary)) do
            modname = Patches.namespace(module, unquote(env.module))

            {:module, _loaded_module} = :code.load_binary(modname, [], binary)
          end

          Patches.namespace(module, unquote(env.module))
        end
      end
    ] ++ wrappers(modules_and_modifications, namespaced_modules)
  end

  defmacro patch(module) do
    quote do
      @module_patches unquote(module)
    end
  end

  defmacro export(module, function, arity) do
    quote do
      @exports {unquote(module), unquote(function), unquote(arity)}
    end
  end

  defmacro replace(module, function, arity, replacement_function \\ nil)

  defmacro replace(module, function, arity, nil) do
    quote do
      @replacers {unquote(module), unquote(function), unquote(arity), unquote(function)}
    end
  end

  defmacro replace(module, function, arity, replacement_function) do
    quote do
      @replacers {unquote(module), unquote(function), unquote(arity),
                  unquote(replacement_function)}
    end
  end

  defmacro wrap(module, function, wrapping_function) when is_atom(wrapping_function) do
    quote do
      @wrappers {unquote(module), unquote(function), nil, unquote(wrapping_function)}
    end
  end

  defmacro wrap(module, function, arity, wrapping_function) do
    quote do
      @wrappers {unquote(module), unquote(function), unquote(arity), unquote(wrapping_function)}
    end
  end

  @doc false
  def namespace(module, suffix) do
    Module.concat(module, suffix)
  end

  @doc """
  Returns the abstract code from the given module.
  """
  def abstract_code(module) do
    {_, beam, _} = :code.get_object_code(module)

    {:ok, {_, [{:abstract_code, {:raw_abstract_v1, code}}]}} =
      :beam_lib.chunks(beam, ~w/abstract_code/a)

    code
  end

  @doc """
  Manipulates abstract code to exports the given functions.
  """
  def export_functions(code, nil), do: code

  def export_functions(code, functions) do
    {:attribute, line, :export, exports} = List.keyfind(code, :export, 2)

    attr = {:attribute, line, :export, exports ++ functions}

    List.keyreplace(code, :export, 2, attr)
  end

  @doc """
  Manipulates abstract code to replace a function in a module with call to the 
  wrapping module
  """
  def replace_function(code, nothing, _) when is_nil(nothing) or nothing == [], do: code

  def replace_function(code, replacers, wrapping_module) when is_list(replacers),
    do: Enum.reduce(replacers, code, &replace_function(&2, &1, wrapping_module))

  def replace_function(code, {_module, function, arity, remote_function}, wrapping_module) do
    modify_function(code, function, arity, &replace_body(&1, wrapping_module, remote_function))
  end

  @doc false
  def wrap_function(code, nothing, _) when is_nil(nothing) or nothing == [], do: code

  def wrap_function(code, mfws, wrapping_module) when is_list(mfws) do
    Enum.reduce(mfws, code, &wrap_function(&2, &1, wrapping_module))
  end

  def wrap_function(code, {module, function, _}, wrapping_module) do
    do_wrap_function(code, module, function, nil, wrapping_module)
  end

  def wrap_function(code, {module, function, arity, _}, wrapping_module) do
    do_wrap_function(code, module, function, arity, wrapping_module)
  end

  defp do_wrap_function(code, module, function, arity, wrapping_module) do
    code
    |> modify_function(function, arity, &wrap_abstract_function(&1, module, wrapping_module))
  end

  defp modify_function(code, function, arity, func) do
    Enum.reduce(code, [], fn
      {:function, _, ^function, func_arity, _} = function_to_wrap, acc
      when is_nil(arity) or arity == func_arity ->
        [func.(function_to_wrap) | acc]

      line, acc ->
        [line | acc]
    end)
    |> Enum.reverse()
  end

  defp wrap_abstract_function(function_tuple, origin, wrapping_module) do
    {:function, line, function, arity, clauses} = function_tuple

    clauses =
      for {:clause, clause_line, args, guards, body} <- clauses do
        new_body = [
          {:call, line, {:remote, line, {:atom, line, wrapping_module}, {:atom, line, :wrap}},
           [
             {:tuple, line,
              [{:atom, line, origin}, {:atom, line, function}, {:integer, line, arity}]},
             {:fun, line, {:clauses, [{:clause, line, [], [], body}]}}
           ]}
        ]

        {:clause, clause_line, args, guards, new_body}
      end

    {:function, line, function, arity, clauses}
  end

  defp replace_body(function_tuple, remote_module, remote_function) do
    {:function, line, function, arity, clauses} = function_tuple

    new_clauses =
      for {:clause, clause_line, args, _guards, _body} <- clauses do
        # If pattern matching is used in the arguments, the args cannot be transplanted in the function call of the replacing function.
        # instead we unmatch the arguments and create variables with the names of their Structs. 
        # To avoid conflicts if two identical modules are used, we append the names with a counter.
        # For example:
        #   def foo(%Bar{buz: buz}, %Bar{})
        # will be normalized to:
        #   def foo(bar1)
        args = normalize_args(args)

        body = [
          {:call, clause_line,
           {:remote, clause_line, {:atom, clause_line, remote_module},
            {:atom, clause_line, remote_function}}, args}
        ]

        {:clause, clause_line, args, [], body}
      end

    {:function, line, function, arity, new_clauses}
  end

  defp normalize_args(args) do
    args
    |> Enum.with_index()
    |> Enum.map(fn
      {{_, line, _}, index} ->
        {:var, line, :"arg#{index}@1"}

      {{_, line, _, _}, index} ->
        {:var, line, :"arg#{index}@1"}
    end)
  end

  @doc false
  def compile(code) do
    case :compile.forms(code) do
      {:ok, _modname, binary} ->
        binary

      :error ->
        File.write(
          "/tmp/punkix_compile",
          code
        )

        :error
    end
  end

  defp wrappers(module_map, namespaces) do
    for {module, %{wrap: modifications}} <- module_map do
      Enum.map(modifications, fn
        {_, function, arity, wrapper} ->
          quote do
            def wrap({unquote(namespaces[module]), unquote(function), unquote(arity)}, fun) do
              result = unquote(wrapper)(fun.())
              result
            end
          end

        {_, function, wrapper} ->
          quote do
            def wrap({unquote(namespaces[module]), unquote(function)}, fun) do
              result = unquote(wrapper)(fun.())
              result
            end
          end
      end)
    end
  end
end
