defprotocol StateChart.Context do
  def put_event(model, event)
  def query(model, query)
  def execute(model, command)
end

defimpl StateChart.Context, for: Map do
  def put_event(model, event) do
    Map.put(model, "_event", event)
  end

  def query(model, _) do
    true
  end

  def execute(model, _) do
    model
  end
end
