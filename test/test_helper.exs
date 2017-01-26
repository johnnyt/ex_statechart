defmodule Test.StateChart.Case do
  use ExUnit.CaseTemplate, async: true

  using do
    quote do
      import unquote(__MODULE__)
    end
  end

  def test_scxml(xml, description, initial_state, events) do
    true
  end
end

ExUnit.start()
