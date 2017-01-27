defmodule StateChart.Document do
  use StateChart.Definition do
    enum Binding, :binding, 1, [
      early: 0,
      late: 1
    ]
    field(map(:var, __MODULE__.Data), :datamodel, 2)
    repeated(__MODULE__.Transition, :initial, 3)
    field(:string, :name, 4)
    field(map(:ref, __MODULE__.State), :states, 5)
  end

  alias __MODULE__.{Analyzer,Query,State,Transition}

  def resolve(_, %State{} = s) do
    s
  end
  def resolve(%{states: s}, id) do
    {:ok, state} = Map.fetch(s, id)
    state
  end

  @doc """
  Compute transitions
  """

  def transitions_by(%{states: s} = model, configuration, filter) do
    configuration
    |> Stream.flat_map(fn(%{ancestors: ancestors} = state) ->
      ancestors
      |> resolve_list(s)
      |> Stream.concat([state])
    end)
    |> Stream.flat_map(fn(%{transitions: t}) -> t end)
    |> Stream.filter(filter)
    |> Enum.into(MapSet.new())
    |> priority_enabled_transitions(model)
    |> Enum.sort(&Transition.compare/2)
  end

  defp priority_enabled_transitions(transitions, model) do
    {consistent, inconsistent} = inconsistent_transitions(model, transitions)
    resolve_conflicts(model, consistent, inconsistent)
  end

  defp inconsistent_transitions(model, transitions) do
    inconsistent = transitions
    |> Stream.flat_map(fn(%{scope: s1} = t1) ->
      transitions
      |> Stream.filter(fn(%{scope: s2}) ->
        !Query.orthoganal?(model, s1, s2)
      end)
      |> Stream.map(fn(t2) ->
        if Transition.compare(t1, t2), do: t1, else: t2
      end)
    end)
    |> Enum.into(MapSet.new())

    {MapSet.difference(transitions, inconsistent), inconsistent}
  end

  defp resolve_conflicts(model, consistent, inconsistent) do
    case MapSet.size(inconsistent) do
      0 ->
        consistent
      1 ->
        MapSet.union(consistent, inconsistent)
      _ ->
        {new_consistent, inconsistent} = inconsistent_transitions(model, inconsistent)
        consistent = MapSet.union(consistent, new_consistent)
        resolve_conflicts(model, consistent, inconsistent)
    end
  end

  @doc """
  Compute all of the enter states
  """

  def enter_states(model, configuration, history, transitions) do
    acc = {MapSet.new(), configuration, MapSet.new()}
    acc = transitions
    |> Enum.reduce(acc, fn(%{targets: targets, scope: scope}, acc) ->
      targets
      |> Enum.reduce(acc, &add_state_and_ancestors(model, &1, scope, history, &2))
    end)

    {states, configuration, _} = acc

    # root-first sorting
    states = Enum.sort(states, &State.compare/2)

    {states, configuration}
  end

  defp add_state_and_ancestors(%{states: s} = model, target, scope, history, acc) do
    acc = add_state_and_descendants(model, target, history, acc)

    model
    |> Query.ancestors(target, scope)
    |> resolve_list(s)
    |> Enum.reduce(acc, fn
      (%{type: :composite} = state, {states, configuration, processed}) ->
        states = MapSet.put(states, state)
        processed = MapSet.put(processed, state)
        {states, configuration, processed}
      (state, acc) ->
        add_state_and_descendants(model, state, history, acc)
    end)
  end

  defp add_state_and_descendants(
    %{states: s} = model,
    %{id: id, type: type, parent: parent, children: children} = state,
    history,
    {states, configuration, processed} = acc
  ) do
    if MapSet.member?(processed, state) do
      acc
    else
      processed = MapSet.put(processed, state)
      acc = {states, configuration, processed}

      if type == :history do
        case Map.fetch(history, id) do
          {:ok, history_states} ->
            Enum.reduce(history_states, acc, &add_state_and_ancestors(model, &1, parent, history, &2))
          _ ->
            states = MapSet.put(states, state)
            configuration = MapSet.put(configuration, state)
            {states, configuration, processed}
        end
      else
        states = MapSet.put(states, state)
        case type do
          :parallel ->
            children
            |> resolve_list(s)
            |> Stream.filter(fn(%{type: t}) -> t != :history end)
            |> Enum.reduce(acc, &add_state_and_descendants(model, &1, history, &2))
          :composite ->
            states = MapSet.put(states, state)
            acc = {states, configuration, processed}
            if Enum.any?(children, &MapSet.member?(processed, &1)) do
              acc
            else
              %{initial: i} = state
              add_state_and_descendants(model, i, history, acc)
            end
          t when t in [:initial, :basic, :final] ->
            configuration = MapSet.put(configuration, state)
            {states, configuration, processed}
          true ->
            acc
        end
      end
    end
  end
  defp add_state_and_descendants(%{states: s} = model, id, history, acc) do
    {:ok, state} = Map.fetch(s, id)
    add_state_and_descendants(model, state, history, acc)
  end

  @doc """
  Compute all of the exit states given a transition set and previous configuration
  """

  def exit_states(%{states: s} = model, configuration, transitions) do
    transitions
    |> Stream.filter(fn(%{targets: t}) -> t != [] end)
    |> Enum.reduce({MapSet.new(), configuration}, fn(%Transition{scope: scope}, acc) ->
       {:ok, %{id: scope, descendants_set: desc}} = Map.fetch(s, scope)

        configuration
        |> Stream.filter(&MapSet.member?(desc, &1))
        |> Enum.reduce(acc, fn(state, {states, configuration}) ->
          states = model
            |> Query.ancestors(state, scope)
            |> resolve_list(s)
            |> Enum.into(states)

          configuration = MapSet.delete(configuration, state)

          {states, configuration}
        end)
    end)
    |> case do
      {states, configuration} ->
        # leaf-node first sorting
        states = Enum.sort(states, &!State.compare(&1, &2))
        {states, configuration}
    end
  end

  defp resolve_list(list, s) do
    Stream.map(list, fn(id) ->
      {:ok, state} = Map.fetch(s, id)
      state
    end)
  end
end
