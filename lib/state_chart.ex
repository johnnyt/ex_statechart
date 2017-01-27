defmodule StateChart do
  alias __MODULE__.{Context,Interpreter,Event}

  def interpret(doc, context) do
    int = Interpreter.new(doc)
    {:sync, int, context} = Interpreter.start(int, context)
    context = Context.sync(context)
    resume(int, context)
  end

  def handle_event(int, event, context) do
    event = Event.new(event)
    {:sync, int, context} = Interpreter.handle_event(int, event, context)
    context = Context.sync(context)
    resume(int, context)
  end

  defp resume(int, context) do
    case Interpreter.resume(int, context) do
      {:await, int, context} ->
        {:await, int, context}
      {:done, int, context} ->
        context = Context.done(context)
        {:done, int, context}
      # TODO this shouldn't happen
      {:sync, int, context} ->
        {:await, int, context}
    end
  end
end
