defmodule HomeSensors.Dev do
  @moduledoc """
  `HomeSensors.Dev` is host code for ui and tests.
  """

  def history_test do
    [
      ["17:06", 80.0, 59.5, 88, 74.1, 54.8, 100],
      ["17:04", 80.0, 59.5, 88, 73.9, 54.8, 100]
    ]
  end

  require Logger
  use GenServer

  def start_link(_init_arg) do
    GenServer.start_link(__MODULE__, nil, name: HomeSensors)
  end

  @impl GenServer
  def init(_init_arg) do
    Logger.info("running #{__MODULE__}")
    {:ok, %{updates: []}}
  end

  @aqi "AQI 41 PM2.5 is Good. AQI 12 PM10 is Good. At 12:00 in Chattanooga, TN 37404."

  @impl GenServer
  def handle_cast({:subscribe, pid}, state) do
    Logger.info("#{__MODULE__} subscribe #{inspect(pid)}")
    send(pid, {:history, history_test()})
    send(pid, {:aqi, @aqi})
    {:noreply, state}
  end

  def handle_cast(cast, state) do
    Logger.info("#{__MODULE__} handle_cast #{inspect(cast)}")
    {:noreply, state}
  end
end
