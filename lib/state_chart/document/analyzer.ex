defmodule StateChart.Document.Analyzer do
  alias StateChart.Document.{State,Transition}
  alias StateChart.Runtime.Invoke

  def ref(%{__states__: s}) do
    map_size(s)
  end

  def deref(_, nil) do
    nil
  end
  def deref(%{__states__: s}, name) do
    {:ok, %{ref: ref}} = Map.fetch(s, name)
    ref
  end

  def on_enter(doc, state, ancestors) do
    {state, doc} = put_state(doc, state)
    %{id: id} = state
    ancestors = [id | ancestors]
    {doc, state, ancestors}
  end

  def on_exit(doc, state, children) do
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
      invocations: invocations,
      on_entry: on_entry,
      on_exit: on_exit,
      transitions: transitions}
    |> handle_initial_composite()
    |> handle_history_composite()
    |> update_doc(doc)
  end

  def finalize(doc, _opts) do
    doc
    |> finalize_references()
    |> finalize_initial()
    |> finalize_states()
  end

  defp put_state(%{initial: i} = doc, %{id: id} = state) when i in [[], nil] do
    %{doc | initial: [id]}
    |> put_state(state)
  end
  defp put_state(%{__states__: s} = doc, %{id: id} = state) do
    case Map.fetch(s, id) do
      :error ->
        {state, %{doc | __states__: Map.put(s, id, state)}}
      _ ->
        raise ArgumentError, "redefinition of state id #{id}"
    end
  end

  defp update_doc(%{id: id} = state, %{__states__: s} = doc) do
    s = Map.put(s, id, state)
    {state, %{doc | __states__: s}}
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

  defp finalize_references(%{__states__: s} = doc) do
    s = s
    |> Enum.map_reduce(0, fn({id, %{initials: init, transitions: trans, children: children, depth: depth} = state}, idx) ->
      check_refs!(s, init, fn(ref) ->
        "Unable to locate initial targets for state: #{id} (#{inspect(init)})"
      end)

      idx = idx + 1
      priority = idx

      {trans, idx} = trans
      |> Enum.map_reduce(idx, fn(transition, idx) ->
        transition = %{transition | source: id, depth: depth, priority: idx}
        transition = check_targets!(transition, s)
        lcca = find_lcca(transition, s)
        {%{transition | scope: get_scope(transition, lcca, s)}, idx + 1}
      end)

      children = Enum.map(children, fn(%{id: id}) -> id end)

      {{id, %{state | transitions: trans, children: children, priority: priority}}, idx}
    end)
    |> elem(0)
    |> Enum.into(%{})

    %{doc | __states__: s}
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

  defp check_targets!(%{source: id, targets: []} = t, _s) do
    %{t | targets: [id]}
  end
  defp check_targets!(%{source: id, targets: targets} = t, s) do
    check_refs!(s, targets, fn(refs) ->
      "Unable to locate transition targets #{inspect(refs)} for state: #{id}"
    end)
    t
  end

  defp check_refs!(s, list, message) do
    list
    |> Enum.filter(&!check_ref(s, &1))
    |> case do
      [] ->
        nil
      refs ->
        raise ArgumentError, message.(refs)
    end
  end

  defp check_ref(_, nil), do: true
  defp check_ref(s, id), do: Map.fetch(s, id) != :error

  defp finalize_initial(%{initial: initial} = doc) do
    targets = Enum.map(initial, &deref(doc, &1))
    transition = %Transition{targets: targets}
    %{doc | initial: transition}
  end

  defp finalize_states(%{__states__: s} = doc) do
    states = :erlang.make_tuple(map_size(s), nil)
    states = Enum.reduce(s, states, fn({_, %{ref: ref} = state}, states) ->
      put_elem(states, ref, State.finalize(state, doc))
    end)
    %{doc | states: states, __states__: %{}}
  end
end
