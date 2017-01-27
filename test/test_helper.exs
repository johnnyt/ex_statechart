defmodule Test.StateChart.Case do
  alias StateChart.{Configuration,Event,Interpreter,Model}
  use ExUnit.CaseTemplate, async: true

  using do
    quote do
      import unquote(__MODULE__)
    end
  end

  def test_scxml(xml, _description, initial_state, events) do
    datamodels = %{
      "ecmascript" => StateChart.DataModel.ECMA,
      "elixir" => StateChart.DataModel.Elixir,
      "null" => StateChart.DataModel.Null
    }

    opts = %{datamodels: datamodels}

    model = xml |> StateChart.SCXML.parse(opts)

    # TODO
    # datastore = DataStore.new(model)
    # datastore = %{}
    # int = Interpreter.new(model, datastore)
    # run(int, initial_state, events)
    :ok
  end

  defp run(int, conf, events) do
    {:sync, int} = Interpreter.start(int)
    resume(int, conf, events)
  end

  defp loop(int, []) do
    Interpreter.stop(int)
  end
  defp loop(int, [{event, conf} | events]) do
    {:sync, int} = Interpreter.handle_event(int, Event.new(event))
    resume(int, conf, events)
  end

  defp resume(int, conf, events) do
    case Interpreter.resume(int) do
      {:await, int} ->
        assert_configuration(int, conf)
        loop(int, events)
      {:sync, int} ->
        # TODO recurse instead?
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

  defp assert_done(int, events) do
    expected = []
    actual = Enum.map(events, fn({event, _}) -> Event.new(event) end)
    assert expected == actual
    int
  end
end

ExUnit.start()
