defmodule StateChart.Definition do
  defmacro __using__([do: block]) do
    quote do
      import unquote(__MODULE__)
      var!(fields) = []
      var!(struct) = []
      unquote(block)
      defstruct var!(struct)

      def new(params \\ %{})
      def new(%__MODULE__{} = model) do
        # TODO should we recast everything just to make sure it's all valid?
        model
      end
      def new(params) do
        Enum.reduce(params, %__MODULE__{}, &cast_field/2)
      end
      defoverridable new: 1

      @fields :lists.reverse(var!(fields))
      def fields do
        @fields
      end
    end
  end

  defmacro field(type, name, id, aliases \\ []) do
    quote bind_quoted: [
      type: type,
      name: name,
      id: id,
      aliases: aliases
    ] do
      # TODO put type-specific default here
      default = StateChart.Definition.__default__(type)
      var!(struct) = [{name, default} | var!(struct)]
      var!(fields) = [{type, name, id, :one} | var!(fields)]

      names = [name, to_string(name) | Enum.flat_map(aliases, fn(a) ->
        [a, to_string(a)]
      end)]

      defp cast_field({k, nil}, model) when k in unquote(names) do
        model
      end
      defp cast_field({k, v}, model) when k in unquote(names) do
        value = StateChart.Definition.__cast__(unquote(Macro.escape(type)), v)
        %{model | unquote(name) => value}
      end
    end
  end

  defmacro enum(type, name, id, values) do
    quote bind_quoted: [
      type: type,
      name: name,
      id: id,
      values: values
    ] do
      # TODO define module/struct
      {default, 0} = hd(values)
      var!(struct) = [{name, default} | var!(struct)]
      var!(fields) = [{type, name, id} | var!(fields)]

      names = [name, to_string(name)]

      defp cast_field({k, nil}, model) when k in unquote(names) do
        model
      end
      for {value, _id} <- values do
        defp cast_field({k, v}, model)
        when k in unquote(names)
         and v in unquote([value, to_string(value)]) do
          %{model | unquote(name) => v}
        end
      end
    end
  end

  defmacro repeated(type, name, id) do
    quote bind_quoted: [
      type: type,
      name: name,
      id: id
    ] do
      var!(struct) = [{name, []} | var!(struct)]
      var!(fields) = [{type, name, id, :many} | var!(fields)]

      names = [name, to_string(name)]

      defp cast_field({k, nil}, model) when k in unquote(names) do
        model
      end
      defp cast_field({k, v}, model) when k in unquote(names) and is_list(v) do
        %{model | unquote(name) => v}
      end
    end
  end

  defmacro computed(name, fun) do
    quote do
      var!(struct) = [{unquote(name), nil} | var!(struct)]
      # TODO execute function
    end
  end

  def map(key, value) do
    {:__MAP__, key, value}
  end

  def __cast__(:string, value) do
    to_string(value)
  end
  def __cast__(:ref, value) do
    # We'll keep it as it is for now
    value
  end
  def __cast__(:var, value) do
    # We'll keep it as it is for now
    value
  end
  def __cast__(:any, value) do
    value
  end

  def __default__(:string), do: ""
  def __default__(:bool), do: false
  def __default__(:uint32), do: 0
  def __default__({:__MAP__, _, _}), do: %{}
  def __default__(_), do: nil
end
