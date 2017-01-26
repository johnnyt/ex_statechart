defmodule StateChart.Model.State do
  defstruct [
    id: nil,
    type: :composite,
    children: [],
    initial: nil,
    invocations: [],
    on_entry: [],
    on_exit: [],
    transitions: [],

    ancestors: [],
    ancestors_set: MapSet.new(),
    descendants: [],
    descendants_set: MapSet.new(),
    depth: 0,
    priority: nil,
    parent: nil,
    history: nil,
    is_deep: nil
  ]

  def new(%__MODULE__{} = m, ancestors, gen_id) do
    m
    |> maybe_generate_id(gen_id)
    |> handle_ancestors(ancestors)
    |> maybe_basic()
    |> maybe_wrap()
  end
  def new(info, ancestors, gen_id) do
    info
    |> Enum.reduce(%__MODULE__{}, &handle_kv/2)
    |> new(ancestors, gen_id)
  end

  def compare(%{priority: p}, %{priority: p}), do: true
  def compare(%{priority: {d, p1}}, %{priority: {d, p2}}) do
    p1 < p2
  end
  def compare(%{priority: {d1, _}}, %{priority: {d2, _}}) do
    d1 >= d2
  end

  def on_enter(%{on_entry: on_entry}, datastore) do
    Enum.reduce(on_entry, datastore, &StateChart.DataStore.execute(&2, &1))
  end

  def on_exit(%{on_exit: on_exit}, datastore) do
    Enum.reduce(on_exit, datastore, &StateChart.DataStore.execute(&2, &1))
  end

  defp handle_kv({_, nil}, acc), do: acc
  defp handle_kv({k, v}, acc) when k in [:id, "id"] do
    %{acc | id: v}
  end
  defp handle_kv({k, v}, acc) when k in [:type, "$type"] do
    %{acc | type: parse_type(v)}
  end
  defp handle_kv({k, v}, acc) when k in [:child, "child", :children, "children", :states, "states", :substates, "substates"] do
    %{acc | children: parse_list(v)}
  end
  defp handle_kv({k, v}, acc) when k in [:initial, "initial"] do
    %{acc | initial: v}
  end
  defp handle_kv({k, v}, acc) when k in [:on_entry, "on_entry", :onEntry, "onEntry"] do
    %{acc | on_entry: parse_list(v)}
  end
  defp handle_kv({k, v}, acc) when k in [:on_exit, "on_exit", :onExit, "onExit"] do
    %{acc | on_exit: parse_list(v)}
  end
  defp handle_kv({k, v}, acc) when k in [:transition, "transition", :transitions, "transitions"] do
    %{acc | transitions: Enum.map(parse_list(v), &StateChart.Model.Transition.new/1)}
  end
  defp handle_kv({k, v}, acc) when k in [:is_deep, "is_deep", :isDeep, "isDeep"] and is_boolean(v) do
    %{acc | is_deep: v}
  end
  defp handle_kv({"", _}, acc) do # This is just saying it's a statechart
    acc
  end

  defp parse_list(t) when is_list(t), do: t
  defp parse_list(t), do: [t]

  defp handle_ancestors(m, []) do
    m
  end
  defp handle_ancestors(m, [parent | _] = ancestors) do
    %{m | ancestors: ancestors, ancestors_set: MapSet.new(ancestors), depth: length(ancestors), parent: parent}
  end

  defp maybe_basic(%{type: :composite, children: []} = state) do
    %{state | type: :basic}
  end
  defp maybe_basic(state) do
    state
  end

  defp maybe_wrap(%{depth: 0, type: t, id: id} = state) when t != :composite do
    %__MODULE__{
      id: "#{id}#_wrapper_",
      children: [
        %{
          type: :initial,
          transitions: [
            %{target: id}
          ]
        },
        state
      ]
    }
  end
  defp maybe_wrap(state) do
    state
  end

  types = [
    :parallel,
    :initial,
    :history,
    :final,
    :basic,
    :composite
  ]

  defp parse_type("scxml"), do: :composite
  defp parse_type(:scxml), do: :composite
  defp parse_type("state"), do: :composite
  defp parse_type(:state), do: :composite
  for type <- types do
    defp parse_type(unquote(type)), do: unquote(type)
    defp parse_type(unquote(to_string(type))), do: unquote(type)
  end
  defp parse_type(type) do
    raise ArgumentError, "Invalid state type #{type}"
  end

  defp maybe_generate_id(%{id: nil} = m, gen_id) do
    %{m | id: gen_id.()}
  end
  defp maybe_generate_id(m, _) do
    m
  end
end
