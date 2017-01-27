defmodule StateChart.Event do
  use StateChart.Definition do
    field(:string, :name, 1)
    enum Type, :type, 2, [
      external: 0,
      internal: 1,
      platform: 2
    ]
    field(:string, :sendid, 3)
    field(:string, :origin, 4)
    field(:string, :origintype, 5)
    field(:string, :invokeid, 6)
    field(:any, :data, 7)
  end
end
