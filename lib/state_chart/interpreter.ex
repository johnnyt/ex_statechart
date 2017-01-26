defmodule StateChart.Interpreter do
  require Logger
  defmacrop debug(int, message) do
    quote do
      # TODO add int info (sessionid, name?)
      int = unquote(int)
      Logger.debug(fn -> unquote(message) end)
      int
    end
  end

  alias StateChart.{DataModel,Event,Invocation,Model,Queue}
  alias Model.{Transition,State}

  defstruct [
    model: nil,
    internal_events: Queue.new(),

    configuration: MapSet.new(),
    data_model: %{},
    history: %{},
    running?: true
  ]

  @doc """
  Create an interpreter from a document  
  """

  def new(%Model{} = model, data_model \\ %{}) do
    %__MODULE__{model: model, data_model: data_model}
  end

  @doc """
  Start evaluation of the interpreter
  """

  def start(%__MODULE__{model: %Model{initial: initial}} = int) do
    debug(int, "-> START")
    enter_states(int, initial)
  end

  @doc """
  Handle an external event
  """

  def handle_event(%__MODULE__{} = int, event) do
    {transitions, int} = int
    |> put_event(event)
    |> debug("handle_event: #{inspect(event.name)}")
    |> invoke_event(event)
    |> select_transitions(event)

    microstep(int, transitions)
  end

  @doc """
  Resume execution after a :sync
  """

  def resume(%__MODULE__{internal_events: events} = int) do
    debug(int, "-> RESUME")
    case {select_eventless_transitions(int), int} do
      {[], %{internal_events: %Queue{size: 0}, running?: false} = int} ->
        stop(int)
      {[], %{internal_events: %Queue{size: 0}} = int} ->
        case invoke_states(int) do
          %{internal_events: %Queue{size: 0}} = int ->
            debug(int, "<- AWAIT")
            {:await, int}
          int ->
            resume(int)
        end
      {[], %{internal_events: events} = int} ->
        {event, events} = Queue.dequeue(events)
        
        {transitions, int} = %{int | events: events}
        |> put_event(event)
        |> debug("handle_event: #{inspect(event.name)}")
        |> select_transitions(event)

        microstep(int, transitions)
      {transitions, int} ->
        microstep(int, transitions)
    end
  end

  @doc """
  Cleans up the interpreter
  """

  def stop(%__MODULE__{configuration: configuration} = int) do
    int = configuration
    |> Enum.sort(&!State.compare(&1, &2))
    |> Enum.reduce(int, fn
      (%State{on_exit: oe, invocations: invs} = state, int) ->
        int = Enum.reduce(oe, int, &execute_content(&2, &1))
        int = Enum.reduce(invs, int, &cancel_invocation(&2, &1))
        if final_state?(state) && root?(state) do
          return_done_event(int, nil)
        else
          int
        end
    end)
    {:stop, %{int | configuration: [], running?: false}}
  end

  defp invoke_event(int, event) do
    int
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
  
  defp invoke_states(int) do
    int
  end
  # defp invoke_states(%{to_invoke: to_invoke} = int) do
  #   Enum.reduce(to_invoke, int, fn(%State{invocations: invs}, int) ->
  #     Enum.reduce(invs, int, &invoke(&2, &1))
  #   end)
  # end

  defp return_done_event(int, data) do
    # TODO
    int
  end

  defp select_eventless_transitions(%{configuration: conf, model: model, data_model: data_model = int}) do
    selected = Model.transitions_by(model, conf, fn
      (%Transition{event: nil} = transition) ->
        Transition.on_condition(transition, data_model)
      (_) ->
        false
    end)
    debug(int, "select_transitions: #{inspect(selected)}")
    selected
  end

  defp select_transitions(%{configuration: conf, model: model, data_model: data_model} = int, %Event{name: name}) do
    selected = Model.transitions_by(model, conf, fn
      (%Transition{conditions: conditions} = transition) ->
        Transition.match?(transition, name) && Transition.on_condition(transition, data_model)
      (_) ->
        false
    end)
    debug(int, "select_transitions: #{inspect(selected)}")
    {selected, int}
  end

  defp microstep(int, transitions) do
    int
    |> exit_states(transitions)
    |> execute_transitions(transitions)
    |> enter_states(transitions)
  end

  defp exit_states(
    %{model: model, configuration: conf, data_model: data_model, history: history} = int,
    transitions
  ) do

    {states, conf} = Model.exit_states(model, conf, transitions)
    {history, data_model} = Enum.reduce(states, {data_model, history}, fn(state, {data_model, history}) ->
      data_model = State.on_exit(state, data_model)
      # TODO add history if present
      {data_model, history}
    end)
    debug(int, "exit_states: #{inspect(Enum.map(states, &Map.get(&1, :id)))}")

    %{int | data_model: data_model, configuration: conf, history: history}
  end

  defp execute_transitions(%{data_model: data_model} = int, transitions) do
    data_model = Enum.reduce(transitions, data_model, &Transition.on_transition/2)
    debug(int, "execute_transitions")
    %{int | data_model: data_model}
  end

  defp enter_states(%{model: model, configuration: conf, data_model: data_model, history: history} = int, transitions) do
    {states, conf} = Model.enter_states(model, conf, history, transitions)
    data_model = Enum.reduce(states, data_model, &State.on_enter/2)
    debug(int, "enter_states: #{inspect(Enum.map(states, &Map.get(&1, :id)))}")
    debug(int, "<- SYNC")
    {:sync, %{int | data_model: data_model, configuration: conf}}
  end

  defp final_state?(state) do
    # TODO
    false
  end

  defp root?(state) do
    # TODO
    false
  end

  defp execute_content(int, content) do
    # TODO
    int
  end

  defp apply_finalize(int, invocation, event) do
    # TODO
    int
  end

  defp send(int, id, event) do
    # TODO
    int
  end

  defp invoke(int, %Invocation{}) do
    # TODO
    int
  end

  defp cancel_invocation(int, %Invocation{}) do
    # TODO
    int
  end

  defp exit_order(list) do
    :lists.reverse(list)
  end

  defp put_event(%{data_model: dm} = int, value) do
    %{int | data_model: DataModel.put_event(dm, value)}
  end
end
