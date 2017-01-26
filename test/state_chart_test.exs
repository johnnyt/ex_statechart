defmodule StateChartTest do
  use ExUnit.Case, async: true

  alias StateChart.{Configuration,Event,Interpreter,Model}

  statecharts = Path.wildcard(__DIR__ <> "/cases/**/*.sc.json")

  for sc <- statecharts do
    dir = Path.dirname(sc)
    name = Path.basename(sc, ".sc.json")
    test = Path.join(dir, name <> ".test.json")

    test name do
      sc = File.read!(unquote(sc)) |> Poison.decode!()
      test = File.read!(unquote(test)) |> Poison.decode!()

      sc
      |> Model.new()
      |> Interpreter.new()
      |> run(test)
    end
  end

  defp run(int, %{"initialConfiguration" => conf, "events" => events}) do
    {:sync, int} = Interpreter.start(int)
    case Interpreter.resume(int) do
      {:await, int} ->
        assert_configuration(int, conf)
        loop(int, events)
      {:done, int} ->
        assert_done(int, events)
    end
  end

  defp assert_configuration(int, expected) do
    expected = MapSet.new(expected)
    actual = Configuration.active_states(int)
    assert expected == actual
  end

  defp loop(int, []) do
    Interpreter.stop(int)
  end
  defp loop(int, [%{"event" => event, "nextConfiguration" => conf} | events]) do
    {:sync, int} = Interpreter.handle_event(int, Event.new(event))
    case Interpreter.resume(int) do
      {:await, int} ->
        assert_configuration(int, conf)
        loop(int, events)
      {:done, int} ->
        assert_done(int, events)
    end
  end

  defp assert_done(int, events) do
    expected = []
    actual = Enum.map(events, Event.new/1)
    assert expected == actual
    int
  end
end
