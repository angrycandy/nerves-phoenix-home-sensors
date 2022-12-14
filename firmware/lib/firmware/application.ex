defmodule Firmware.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Firmware.Supervisor]

    children =
      [
        {Task, &Firmware.MigrationHelpers.migrate/0}
        # Children for all targets
        # Starts a worker by calling: Firmware.Worker.start_link(arg)
        # {Firmware.Worker, arg},
      ] ++ children(target())

    Supervisor.start_link(children, opts)
  end

  # List all child processes to be supervised
  def children(:host) do
    [
      # Children that only run on the host
      # Starts a worker by calling: Firmware.Worker.start_link(arg)
      # {Firmware.Worker, arg},
    ]
  end

  def children(_target) do
    spawn(&stop_blinky_leds/0)

    [
      # Children for all targets except host
      # Starts a worker by calling: Firmware.Worker.start_link(arg)
      # {Firmware.Worker, arg},
      {Firmware.Blue.Supervisor, %{device: "ttyS0"}}
    ]
  end

  def target() do
    Application.get_env(:firmware, :target)
  end

  defp stop_blinky_leds() do
    led_base_path = "/sys/class/leds"

    File.ls!(led_base_path)
    |> Enum.each(fn led ->
      Path.join([led_base_path, led, "trigger"])
      |> File.write("none")
    end)
  end
end
