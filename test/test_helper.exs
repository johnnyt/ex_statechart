defmodule Test.StateChart.W3.Case do
  use ExUnit.CaseTemplate, async: true

  using do
    quote do
      import unquote(__MODULE__)
    end
  end

  def test_w3_xml(xml, description) do
    true
  end
end

ExUnit.start()
