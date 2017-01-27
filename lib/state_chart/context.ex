defprotocol StateChart.Context do
  def sync(context)
  def done(context)
  def put_event(context, event)
  def query(context, query)
  def execute(context, command)
end

defimpl StateChart.Context, for: Map do
  def sync(context) do
    context
  end

  def done(context) do
    context
  end

  def put_event(context, event) do
    Map.put(context, "_event", event)
  end

  def query(_context, _) do
    true
  end

  def execute(context, _) do
    context
  end
end
