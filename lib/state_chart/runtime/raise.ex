defmodule StateChart.Runtime.Raise do
  use StateChart.Definition do
    field(:string, :event, 1)
  end
end
