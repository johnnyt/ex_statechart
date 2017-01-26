defmodule StateChart.Model.Transition do
  defstruct [
    source: nil,
    targets: [],
    event: nil,
    conditions: [],
    on_transition: [],

    priority: nil,
    scope: nil,
  ]

  def new(%__MODULE__{} = t) do
    t
  end
  def new(info) do
    Enum.reduce(info, %__MODULE__{}, &handle_kv/2)
  end

  # TODO support pluggable matchers
  def match?(%{event: event}, name) do
    match_event(event, name)
  end

  defp match_event(name, name) do
    true
  end
  defp match_event(event, _) when is_binary(event) do
    false
  end
  defp match_event(event, name) when is_function(event, 1) do
    event.(name)
  end
  defp match_event(event, name) when is_list(event) do
    Enum.any?(event, &match_event(&1, name))
  end

  def compare(%{priority: p}, %{priority: p}), do: true
  def compare(%{priority: {d, p1}}, %{priority: {d, p2}}) do
    p1 < p2
  end
  def compare(%{priority: {d1, _}}, %{priority: {d2, _}}) do
    d1 >= d2
  end

  def on_condition(%{conditions: conditions}, datastore) do
    Enum.all?(conditions, &StateChart.DataStore.query(datastore, &1))
  end

  def on_transition(%{on_transition: on_transition}, datastore) do
    Enum.reduce(on_transition, datastore, &StateChart.DataStore.execute(&2, &1))
  end

  defp handle_kv({_, nil}, acc), do: acc
  defp handle_kv({k, v}, acc) when k in [:target, "target", :targets, "targets"] do
    %{acc | targets: parse_list(v)}
  end
  defp handle_kv({k, v}, acc) when k in [:event, "event", :events, "events"] do
    %{acc | event: parse_list(v)}
  end
  defp handle_kv({k, v}, acc) when k in [:cond, "cond", :condition, "condition", :conditions, "conditions"] do
    %{acc | conditions: parse_list(v)}
  end
  defp handle_kv({k, v}, acc) when k in [:on_transition, "on_transition", :onTransition, "onTransition"] do
    %{acc | on_transition: parse_list(v)}
  end

  defp parse_list(t) when is_list(t), do: t
  defp parse_list(t), do: [t]
end
