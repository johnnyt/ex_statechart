defmodule StateChart.Document.Data do
  use StateChart.Definition do
    field(:string, :id, 1)
    field(:src, :id, 2)
    field(:any, :expression, 3)
  end
end
