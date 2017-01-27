defmodule StateChart.Interpreter do
  require Logger
  defmacrop debug(int, message) do
    quote do
      # TODO add int info (sessionid, name?)
      int = unquote(int)
      # Logger.debug(fn -> unquote(message) end)
      int
    end
  end

  alias StateChart.{Context,Event,Document,Queue,Runtime.Invoke}
  alias Document.{Transition,State}

  defstruct [
    document: nil,
    internal_events: Queue.new(),

    configuration: MapSet.new(),
    history: %{},
    running?: true
  ]

  @doc """
  Create an interpreter from a document  
  """

  def new(%Document{} = document) do
    %__MODULE__{document: document}
  end

  @doc """
  Start evaluation of the interpreter
  """

  def start(%__MODULE__{document: %Document{initial: initial}} = int, context) do
    debug(int, "-> START")
    enter_states(int, [initial], context)
  end

  @doc """
  Handle an external event
  """

  def handle_event(%__MODULE__{} = int, event, context) do
    context = Context.put_event(context, event)
    {int, context} = invoke_event(int, event, context)
    transitions = select_transitions(int, event, context)
    microstep(int, transitions, context)
  end

  @doc """
  Resume execution after a :sync
  """

  def resume(%__MODULE__{running?: false} = int, context) do
    {:stop, int, context}
  end
  def resume(%__MODULE__{internal_events: events} = int, context) do
    debug(int, "-> RESUME")
    case {select_eventless_transitions(int, context), int} do
      {[], %{internal_events: %Queue{size: 0}, running?: false} = int} ->
        stop(int, context)
      {[], %{internal_events: %Queue{size: 0}} = int} ->
        case invoke_states(int, context) do
          {%{internal_events: %Queue{size: 0}} = int, context} ->
            debug(int, "<- AWAIT")
            {:await, int, context}
          {int, context} ->
            resume(int, context)
        end
      {[], %{internal_events: events} = int} ->
        {event, events} = Queue.dequeue(events)
        context = Context.put_event(context, event)
        transitions = %{int | events: events}
        |> debug("handle_event: #{inspect(event.name)}")
        |> select_transitions(event, context)
        microstep(int, transitions, context)
      {transitions, int} ->
        microstep(int, transitions, context)
    end
  end

  @doc """
  Cleans up the interpreter
  """

  def stop(%__MODULE__{configuration: configuration} = int, context) do
    context = configuration
    |> Enum.sort(&!State.compare(&1, &2))
    |> Enum.reduce(context, fn
      (%State{invocations: invs} = state, context) ->
        context = State.on_exit(state, context)
        Enum.reduce(invs, context, &cancel_invocation(&2, &1))
    end)
    {:stop, %{int | configuration: [], running?: false}, context}
  end

  defp invoke_event(int, event, context) do
    {int, context}
  end
  # defp invoke_event(%{configuration: configuration} = int, %Event{invoke_id: id} = event) do
  #   Enum.reduce(configuration, int, fn(%State{invocations: invs}, int) ->
  #     Enum.reduce(invs, int, fn
  #       (%Invocation{invoke_id: ^id} = i) ->
  #         apply_finalize(int, i, event)
  #       (%Invocation{autoforward: true, id: id}) ->
  #         send(int, id, event)
  #       (_) ->
  #         int
  #     end)
  #   end)
  # end

  defp invoke_states(int, context) do
    {int, context}
  end
  # defp invoke_states(%{to_invoke: to_invoke} = int) do
  #   Enum.reduce(to_invoke, int, fn(%State{invocations: invs}, int) ->
  #     Enum.reduce(invs, int, &invoke(&2, &1))
  #   end)
  # end

  defp select_eventless_transitions(%{configuration: conf, document: document} = int, context) do
    selected = Document.transitions_by(document, conf, fn
      (%Transition{events: []} = transition) ->
        Transition.on_condition(transition, context)
      (_) ->
        false
    end)
    debug(int, "select_transitions: #{inspect(selected)}")
    selected
  end

  defp select_transitions(%{configuration: conf, document: document} = int, %Event{name: name}, context) do
    selected = Document.transitions_by(document, conf, fn
      (%Transition{} = transition) ->
        Transition.match?(transition, name) && Transition.on_condition(transition, context)
      (_) ->
        false
    end)
    debug(int, "select_transitions: #{inspect(selected)}")
    selected
  end

  defp microstep(int, transitions, context) do
    {int, context} = exit_states(int, transitions, context)
    {int, context} = execute_transitions(int, transitions, context)
    enter_states(int, transitions, context)
  end

  defp exit_states(
    %{document: document, configuration: conf, history: history} = int,
    transitions,
    context
  ) do
    {states, conf} = Document.exit_states(document, conf, transitions)
    {context, history} = Enum.reduce(states, {context, history}, fn(state, {context, history}) ->
      context = State.on_exit(state, context)
      # TODO add history if present
      {context, history}
    end)
    debug(int, "exit_states: #{inspect(Enum.map(states, &Map.get(&1, :id)))}")

    {%{int | configuration: conf, history: history}, context}
  end

  defp execute_transitions(int, transitions, context) do
    context = Enum.reduce(transitions, context, &Transition.on_transition/2)
    debug(int, "execute_transitions")
    {int, context}
  end

  defp enter_states(%{document: document, configuration: conf, history: history} = int, transitions, context) do
    {states, conf} = Document.enter_states(document, conf, history, transitions)
    context = Enum.reduce(states, context, &State.on_enter/2)
    debug(int, "enter_states: #{inspect(Enum.map(states, &Map.get(&1, :id)))}")
    debug(int, "<- SYNC")
    {:sync, %{int | configuration: conf}, context}
  end

  defp invoke(int, %Invoke{}) do
    # TODO
    int
  end

  defp cancel_invocation(int, %Invoke{}) do
    # TODO
    int
  end
end
