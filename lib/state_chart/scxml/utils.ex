defmodule StateChart.SCXML.Utils do
  import StateChart.SCXML.Parser

  defmacro defchild({name, _, _}, types, not_found_handler \\ nil) do
    types = Enum.map(types, fn(type) ->
      call = case type do
        :else -> :else_
        t -> t
      end
      quote do
        unquote(to_string(type)) ->
          unquote(call)(doc, el, ancestors, opts)
      end |> hd()
    end)

    defaults = quote do
      :text ->
        {nil, doc}
      :comment ->
        {nil, doc}
      _ ->
        IO.inspect {:unrecognized, el}
        {nil, doc}
    end

    quote do
      defp unquote(name)(doc, el, ancestors, opts) do
        case scxml_tag(el), do: unquote(types ++ defaults)
      end
    end
  end

  def string() do
    fn
      (value) when is_binary(value) ->
        value
      (_) ->
        throw :invalid
    end
  end

  def boolean() do
    fn(value) ->
      value in ["true", "TRUE"]
    end
  end

  def enum(values) do
    fn(value) ->
      if value in values do
        value
      else
        throw :invalid
      end
    end
  end

  def uri() do
    fn(value) ->
      # TODO validate
      value
    end
  end
  
  def datamodel(%{datamodels: dms}) do
    fn(value) ->
      case Map.fetch(dms, value) do
        {:ok, parser} ->
          # TODO init parser
          {value, parser}
        _ ->
          throw {:invalid_datamodel, value}
      end
    end
  end

  def expr(doc) do
    fn(expr) ->
      {:TODO, :EXPR, expr}
    end
  end

  def var(doc) do
    fn(name) ->
      {:TODO, :VAR, name}
    end
  end

  def path_expr(doc) do
    fn(name) ->
      {:TODO, :PATHEXPR, name}
    end
  end

  def delay_spec() do
    fn(value) ->
      value
    end
  end

  def delay_expr(doc) do
    fn(value) ->
      {:TODO, :DELAYEXPR, value}
    end
  end

  def uri_expr(doc) do
    fn(value) ->
      {:TODO, :URIEXPR, value}
    end
  end

  def space_list(fun) do
    fn(value) ->
      Regex.split(~r/\s+/, value)
      |> Enum.map(fun)
    end
  end

  def default(fun, value) do
    {:__default__, value, fun}
  end

  def rename(fun, name) do
    # TODO
    fun
  end

  def push_scope(doc, vars) do
    doc
  end

  def pop_scope(doc) do
    doc
  end

  def required(fun) do
    # TODO
    fun
  end

  def traverse(doc, xml_element(content: content), ancestors, opts, fun) do
    Enum.flat_map_reduce(content, doc, fn(child, doc) ->
      case fun.(doc, child, ancestors, opts) do
        {nil, doc} ->
          {[], doc}
        {child, doc} ->
          {[child], doc}
      end
    end)
  end

  def fetch_attrs!(xml_element(attributes: attrs), spec) do
    acc = Stream.map(spec, fn
      ({k, v}) when is_atom(k) ->
        {k, v}
      ({k, {:__default__, value, _}}) ->
        {k, value}
      ({k, _}) ->
        {k, nil}
    end) |> Enum.into(%{})
    Enum.reduce(attrs, acc, fn(xml_attribute(name: name, value: value), acc) ->
      case Map.fetch(spec, name) do
        {:ok, s} ->
          Map.put(acc, name, cast(s, value))
        _ ->
          acc
      end
    end)
  end

  # TODO make sure it's in the namespace and dereference it
  def scxml_tag(xml_element(nsinfo: {_, name})) do
    name
  end
  def scxml_tag(xml_element(name: name)) do
    name
  end
  def scxml_tag(xml_text()) do
    :text
  end
  def scxml_tag(xml_comment()) do
    :comment
  end

  def cast({:__default__, _, f}, v) do
    cast(f, v)
  end
  def cast(f, v) when is_function(f) do
    f.(v)
  end
  def cast(v, v) do
    v
  end
  def cast(s, v) when is_float(s) and is_binary(v) do
    v = String.to_float(v)
    cast(s, v)
  end
end