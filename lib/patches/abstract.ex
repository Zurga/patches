defmodule Patches.Abstract do
  @moduledoc """
  Transformations from erlang abstract syntax

  The abstract syntax is rather tersely defined here:
  https://www.erlang.org/doc/apps/erts/absform.html
  """

  def rewrite(abstract_format, module_callback) when is_list(abstract_format) do
    Enum.map(abstract_format, &rewrite(&1, module_callback))
  end

  def rewrite(abstract_format, module_callback) do
    do_rewrite(abstract_format, module_callback)
  end

  # 8.1  Module Declarations and Forms

  defp do_rewrite({:attribute, anno, :export, exported_functions}, module_callback) do
    {:attribute, anno, :export, rewrite(exported_functions, module_callback)}
  end

  defp do_rewrite({:attribute, anno, :behaviour, module}, module_callback) do
    {:attribute, anno, :behaviour, rewrite_module(module, module_callback)}
  end

  defp do_rewrite({:attribute, anno, :import, {module, funs}}, module_callback) do
    {:attribute, anno, :import,
     {rewrite_module(module, module_callback), rewrite(funs, module_callback)}}
  end

  defp do_rewrite({:attribute, anno, :module, mod}, module_callback) do
    {:attribute, anno, :module, rewrite_module(mod, module_callback)}
  end

  defp do_rewrite({:attribute, anno, :__impl__, attrs}, module_callback) do
    {:attribute, anno, :__impl__, rewrite(attrs, module_callback)}
  end

  defp do_rewrite({:function, anno, name, arity, clauses}, module_callback) do
    {:function, anno, name, arity, rewrite(clauses, module_callback)}
  end

  defp do_rewrite({:attribute, anno, spec, {{name, arity}, spec_clauses}}, module_callback) do
    {:attribute, anno, rewrite(spec, module_callback),
     {{name, arity}, rewrite(spec_clauses, module_callback)}}
  end

  defp do_rewrite({:attribute, anno, :spec, {{mod, name, arity}, clauses}}, module_callback) do
    {:attribute, anno, :spec,
     {{rewrite(mod, module_callback), name, arity}, rewrite(clauses, module_callback)}}
  end

  defp do_rewrite({:attribute, anno, :record, {name, fields}}, module_callback) do
    {:attribute, anno, :record,
     {rewrite_module(name, module_callback), rewrite(fields, module_callback)}}
  end

  defp do_rewrite({:attribute, anno, type, {name, type_rep, clauses}}, module_callback) do
    {:attribute, anno, type,
     {name, rewrite(type_rep, module_callback), rewrite(clauses, module_callback)}}
  end

  defp do_rewrite({:for, target}, module_callback) do
    # Protocol implementation
    {:for, rewrite_module(target, module_callback)}
  end

  defp do_rewrite({:protocol, protocol}, module_callback) do
    {:protocol, rewrite_module(protocol, module_callback)}
  end

  # Record Fields

  defp do_rewrite({:record_field, anno, repr}, module_callback) do
    {:record_field, anno, rewrite(repr, module_callback)}
  end

  defp do_rewrite({:record_field, anno, repr_1, repr_2}, module_callback) do
    {:record_field, anno, rewrite(repr_1, module_callback), rewrite(repr_2, module_callback)}
  end

  defp do_rewrite({:typed_record_field, {:record_field, anno, repr_1}, repr_2}, module_callback) do
    {:typed_record_field, {:record_field, anno, rewrite(repr_1, module_callback)},
     rewrite(repr_2, module_callback)}
  end

  defp do_rewrite(
         {:typed_record_field, {:record_field, anno, repr_a, repr_e}, repr_t},
         module_callback
       ) do
    {:typed_record_field,
     {:record_field, anno, rewrite(repr_a, module_callback), rewrite(repr_e, module_callback)},
     rewrite(repr_t, module_callback)}
  end

  # Representation of Parse Errors and End-of-File Omitted; not necessary
  # 8.2  Atomic Literals

  # only rewrite atoms, since they might be modules
  defp do_rewrite({:atom, anno, literal}, module_callback) do
    {:atom, anno, rewrite_module(literal, module_callback)}
  end

  # 8.3  Patterns
  # ignore bitstraings, they can't contain modules

  defp do_rewrite({:match, anno, lhs, rhs}, module_callback) do
    {:match, anno, rewrite(lhs, module_callback), rewrite(rhs, module_callback)}
  end

  defp do_rewrite({:cons, anno, head, tail}, module_callback) do
    {:cons, anno, rewrite(head, module_callback), rewrite(tail, module_callback)}
  end

  defp do_rewrite({:map, anno, matches}, module_callback) do
    {:map, anno, rewrite(matches, module_callback)}
  end

  defp do_rewrite({:op, anno, op, lhs, rhs}, module_callback) do
    {:op, anno, op, rewrite(lhs, module_callback), rewrite(rhs, module_callback)}
  end

  defp do_rewrite({:op, anno, op, pattern}, module_callback) do
    {:op, anno, op, rewrite(pattern, module_callback)}
  end

  defp do_rewrite({:tuple, anno, patterns}, module_callback) do
    {:tuple, anno, rewrite(patterns, module_callback)}
  end

  defp do_rewrite({:var, anno, atom}, module_callback) do
    {:var, anno, rewrite_module(atom, module_callback)}
  end

  # 8.4  Expressions

  defp do_rewrite({:bc, anno, rep_e0, qualifiers}, module_callback) do
    {:bc, anno, rewrite(rep_e0, module_callback), rewrite(qualifiers, module_callback)}
  end

  defp do_rewrite({:bin, anno, bin_elements}, module_callback) do
    {:bin, anno, rewrite(bin_elements, module_callback)}
  end

  defp do_rewrite({:bin_element, anno, elem, size, type}, module_callback) do
    {:bin_element, anno, rewrite(elem, module_callback), size, type}
  end

  defp do_rewrite({:block, anno, body}, module_callback) do
    {:block, anno, rewrite(body, module_callback)}
  end

  defp do_rewrite({:case, anno, expression, clauses}, module_callback) do
    {:case, anno, rewrite(expression, module_callback), rewrite(clauses, module_callback)}
  end

  defp do_rewrite({:catch, anno, expression}, module_callback) do
    {:catch, anno, rewrite(expression, module_callback)}
  end

  defp do_rewrite({:fun, anno, {:function, name, arity}}, module_callback) do
    {:fun, anno, {:function, rewrite(name, module_callback), arity}}
  end

  defp do_rewrite({:fun, anno, {:function, module, name, arity}}, module_callback) do
    {:fun, anno,
     {:function, rewrite(module, module_callback), rewrite(name, module_callback), arity}}
  end

  defp do_rewrite({:fun, anno, {:clauses, clauses}}, module_callback) do
    {:fun, anno, {:clauses, rewrite(clauses, module_callback)}}
  end

  defp do_rewrite({:named_fun, anno, name, clauses}, module_callback) do
    {:named_fun, anno, rewrite(name, module_callback), rewrite(clauses, module_callback)}
  end

  defp do_rewrite({:call, anno, {:remote, remote_anno, module, fn_name}, args}, module_callback) do
    {:call, anno, {:remote, remote_anno, rewrite(module, module_callback), fn_name},
     rewrite(args, module_callback)}
  end

  defp do_rewrite({:call, anno, name, args}, module_callback) do
    {:call, anno, rewrite(name, module_callback), rewrite(args, module_callback)}
  end

  defp do_rewrite({:if, anno, clauses}, module_callback) do
    {:if, anno, rewrite(clauses, module_callback)}
  end

  defp do_rewrite({:lc, anno, expression, qualifiers}, module_callback) do
    {:lc, anno, rewrite(expression, module_callback), rewrite(qualifiers, module_callback)}
  end

  defp do_rewrite({:map, anno, expression, clauses}, module_callback) do
    {:map, anno, rewrite(expression, module_callback), rewrite(clauses, module_callback)}
  end

  defp do_rewrite({:maybe_match, anno, lhs, rhs}, module_callback) do
    {:maybe_match, anno, rewrite(lhs, module_callback), rewrite(rhs, module_callback)}
  end

  defp do_rewrite({:maybe, anno, body}, module_callback) do
    {:maybe, anno, rewrite(body, module_callback)}
  end

  defp do_rewrite({:maybe, anno, maybe_body, {:else, anno, else_clauses}}, module_callback) do
    {:maybe, anno, rewrite(maybe_body, module_callback),
     {:else, anno, rewrite(else_clauses, module_callback)}}
  end

  defp do_rewrite({:receive, anno, clauses}, module_callback) do
    {:receive, anno, rewrite(clauses, module_callback)}
  end

  defp do_rewrite({:receive, anno, cases, expression, body}, module_callback) do
    {:receive, anno, rewrite(cases, module_callback), rewrite(expression, module_callback),
     rewrite(body, module_callback)}
  end

  defp do_rewrite({:record, anno, name, fields}, module_callback) do
    {:record, anno, rewrite_module(name, module_callback), rewrite(fields, module_callback)}
  end

  defp do_rewrite({:record_field, anno, record_name, field_name, record_field}, module_callback) do
    {:record_field, anno, rewrite_module(record_name, module_callback), field_name, record_field}
  end

  defp do_rewrite({:try, anno, body, case_clauses, catch_clauses}, module_callback) do
    {:try, anno, rewrite(body, module_callback), rewrite(case_clauses, module_callback),
     rewrite(catch_clauses, module_callback)}
  end

  defp do_rewrite({:try, anno, body, case_clauses, catch_clauses, after_clauses}, module_callback) do
    {:try, anno, rewrite(body, module_callback), rewrite(case_clauses, module_callback),
     rewrite(catch_clauses, module_callback), rewrite(after_clauses, module_callback)}
  end

  # Qualifiers

  defp do_rewrite({:generate, anno, lhs, rhs}, module_callback) do
    {:generate, anno, rewrite(lhs, module_callback), rewrite(rhs, module_callback)}
  end

  defp do_rewrite({:b_generate, anno, lhs, rhs}, module_callback) do
    {:b_generate, anno, rewrite(lhs, module_callback), rewrite(rhs, module_callback)}
  end

  # Associations

  defp do_rewrite({:map_field_assoc, anno, key, value}, module_callback) do
    {:map_field_assoc, anno, rewrite(key, module_callback), rewrite(value, module_callback)}
  end

  defp do_rewrite({:map_field_exact, anno, key, value}, module_callback) do
    {:map_field_exact, anno, rewrite(key, module_callback), rewrite(value, module_callback)}
  end

  # 8.5  Clauses

  defp do_rewrite({:clause, anno, lhs, guards, rhs}, module_callback) do
    {:clause, anno, rewrite(lhs, module_callback), rewrite(guards, module_callback),
     rewrite(rhs, module_callback)}
  end

  # 8.6  Guards
  # Guards seem covered by above clauses

  # 8.7  Types
  defp do_rewrite({:ann_type, anno, clauses}, module_callback) do
    {:ann_type, anno, rewrite(clauses, module_callback)}
  end

  defp do_rewrite({:type, anno, :fun, [{:type, type_anno, :any}, type]}, module_callback) do
    {:type, anno, :fun, [{:type, type_anno, :any}, rewrite(type, module_callback)]}
  end

  defp do_rewrite({:type, anno, :map, key_values}, module_callback) do
    {:type, anno, :map, rewrite(key_values, module_callback)}
  end

  defp do_rewrite({:type, anno, predefined_type, expressions}, module_callback) do
    {:type, anno, rewrite(predefined_type, module_callback),
     rewrite(expressions, module_callback)}
  end

  defp do_rewrite({:remote_type, anno, [module, name, expressions]}, module_callback) do
    {:remote_type, anno,
     [rewrite_module(module, module_callback), name, rewrite(expressions, module_callback)]}
  end

  defp do_rewrite({:user_type, anno, name, types}, module_callback) do
    {:user_type, anno, rewrite_module(name, module_callback), rewrite(types, module_callback)}
  end

  # Catch all
  defp do_rewrite(other, _module_callback) do
    other
  end

  defp rewrite_module({:atom, sequence, literal}, module_callback) do
    {:atom, sequence, rewrite_module(literal, module_callback)}
  end

  defp rewrite_module({:var, anno, name}, module_callback) do
    {:var, anno, rewrite_module(name, module_callback)}
  end

  defp rewrite_module(module, module_callback) do
    module_callback.(module)
  end
end
