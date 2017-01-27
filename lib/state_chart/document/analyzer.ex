defmodule StateChart.Document.Analyzer do
  alias StateChart.Document.{State,Transition}
  alias StateChart.Runtime.Invoke

  @doc """
  Traverse the model
  """

  def analyze(model, root) do
    model
    |> traverse(root, [])
    |> elem(1)
    |> resolve_references()
  end

  def on_enter(model, state, ancestors) do
    {state, model} = put_state(model, state)
    %{id: id} = state
    ancestors = [id | ancestors]
    {model, state, ancestors}
  end

    # children: [],
    # initial: nil,
    # invocations: [],
    # on_entry: [],
    # on_exit: [],
    # transitions: [],

  def on_exit(model, state, children) do
    # TODO don't nuke the previous values in the state
    {children, invocations, on_entry, on_exit, transitions} =
      Enum.reduce(children, {[], [], [], [], []}, fn
        (%State{} = s, {c, i, e, x, t}) -> {[s | c], i, e, x, t}
        (%Invoke{} = s, {c, i, e, x, t}) -> {c, [s | i], e, x, t}
        ({:on_entry, s}, {c, i, e, x, t}) -> {c, i, :lists.reverse(s) ++ e, x, t}
        ({:on_exit, s}, {c, i, e, x, t}) -> {c, i, e, :lists.reverse(s) ++ x, t}
        (%Transition{} = s, {c, i, e, x, t}) -> {c, i, e, x, [s | t]}
      end)

    children = :lists.reverse(children)

    descendants = Enum.flat_map(children, fn(%{id: id, descendants: d}) -> [id | d] end)

    %{state |
      children: children,
      descendants: descendants,
      descendants_set: MapSet.new(descendants),
      invocations: invocations,
      on_entry: on_entry,
      on_exit: on_exit,
      transitions: transitions}
    |> handle_initial_composite()
    |> handle_history_composite()
    |> update_model(model)
  end

  defp traverse(model, state, ancestors) do
    {model, %{children: children} = state, ancestors} = on_enter(model, state, ancestors)
    {children, model} = Enum.map_reduce(children, model, &traverse(&2, &1, ancestors))
    on_exit(model, state, children)
  end

  defp put_state(%{initial: nil} = model, %{id: id} = state) do
    %{model | initial: [%Transition{priority: {0, 0}, scope: id, source: :__start__, target: [id]}]}
    |> put_state(state)
  end
  defp put_state(%{states: s} = model, %{id: id} = state) do
    case Map.fetch(s, id) do
      :error ->
        {state, %{model | states: Map.put(s, id, state)}}
      _ ->
        raise ArgumentError, "redefinition of state id #{id}"
    end
  end

  defp update_model(%{id: id} = state, %{states: s} = model) do
    s = Map.put(s, id, state)
    {state, %{model | states: s}}
  end

  def ref(%{states: s}) do
    map_size(s)
  end

  defp handle_initial_composite(%{type: :composite, children: [first | _] = children} = state) do
    %{id: id} = Enum.find(children, first, fn(%{type: t}) -> t == :initial end)
    %{state | initial: id}
  end
  defp handle_initial_composite(state) do
    state
  end

  defp handle_history_composite(%{type: type, children: children} = state) when type in [:composite, :parallel] do
    %{id: id} = Enum.find(children, %{id: nil}, fn(%{type: t}) -> t == :history end)
    %{state | history: id}
  end
  defp handle_history_composite(state) do
    state
  end

  defp resolve_references(%{states: s} = model) do
    s = s
    |> Enum.map_reduce(0, fn({id, %{initial: init, transitions: trans, children: children, depth: depth} = state}, idx) ->
      check_ref(s, init) || raise ArgumentError, "Unable to locate initial state for state: #{id}"

      idx = idx + 1
      priority = {depth, idx}

      {trans, idx} = trans
      |> Enum.map_reduce(idx, fn(transition, idx) ->
        transition = %{transition | source: id, priority: {depth, idx}}
        check_targets!(transition, s)
        lcca = find_lcca(transition, s)
        {%{transition | scope: get_scope(transition, lcca, s)}, idx + 1}
      end)

      children = Enum.map(children, fn(%{id: id}) -> id end)

      {{id, %{state | transitions: trans, children: children, priority: priority}}, idx}
    end)
    |> elem(0)
    |> Enum.into(%{})

    %{model | states: s}
  end

  defp get_scope(%{targets: [], source: s}, _, _) do
    s
  end
  defp get_scope(%{type: :internal, targets: t, source: s}, lcca, states) do
    case Map.fetch(states, s) do
      {:ok, %{parent: nil, descendants: d}} ->
        if Enum.all?(t, &Enum.member?(d, &1)) do
          s
        else
          lcca
        end
    end
  end
  defp get_scope(_, lcca, _) do
    lcca
  end

  defp find_lcca(%{source: s1, targets: [s2 | _]}, s) do
    {:ok, %{ancestors: anc}} = Map.fetch(s, s1)
    anc
    |> Enum.find(fn(a_id) ->
      {:ok, %{type: a_type, descendants: a_desc}} = Map.fetch(s, a_id)
      a_type == :composite && Enum.member?(a_desc, s2)
    end)
  end

  defp check_targets!(%{source: id, targets: targets}, s) do
    targets
    |> Enum.filter(&!check_ref(s, &1))
    |> case do
      [] ->
        :ok
      refs ->
        raise ArgumentError, "Unable to locate transition targets #{inspect(refs)} for state: #{id}"
    end
  end

  defp check_ref(_, nil), do: true
  defp check_ref(s, id), do: Map.fetch(s, id) != :error
end
