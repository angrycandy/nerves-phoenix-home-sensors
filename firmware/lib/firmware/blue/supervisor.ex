defmodule Firmware.Blue.Supervisor do
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(init_arg) do
    children = [
      {BlueHeronScan, init_arg},
      {HomeSensors, BlueHeronScan}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
