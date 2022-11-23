defmodule HomeSensors.Scanner do
  @moduledoc """
  """

  @doc """
  Enable BLE scanning.

  Returns `:ok` or `{:error, :not_working}` if uninitialized.
  """
  def enable(scanner) do
    GenServer.call(scanner, :scan_enable)
  end

  @doc """
  Disable BLE scanning.

  Returns `:ok`.
  """
  def disable(scanner) do
    GenServer.call(scanner, :scan_disable)
  end

  @doc """
  Get devices.

      iex> BlueHeronScan.devices()
      {:ok, %{}}
  """
  def devices(scanner) do
    GenServer.call(scanner, :devices)
  end

  @doc """
  Clear devices from the state.

      iex> BlueHeronScan.clear_devices()
      :ok
  """
  def clear_devices(scanner) do
    GenServer.call(scanner, :clear_devices)
  end

  def accept_cids(scanner, cids \\ nil) do
    GenServer.call(scanner, {:accept_cids, cids})
  end

  @doc """
  Get or set the company IDs to ignore.

  https://www.bluetooth.com/specifications/assigned-numbers

  Apple and Microsoft beacons, 76 & 6, are noisy.

  ## Examples

      iex> HomeSensors.Scanner.ignore_cids(BlueHeronScan)
      {:ok, [6, 76]}
      iex> HomeSensors.Scanner.ignore_cids(BlueHeronScan, [6, 76, 117])
      {:ok, [6, 76, 117]}
  """
  def ignore_cids(scanner, cids \\ nil) do
    GenServer.call(scanner, {:ignore_cids, cids})
  end

  @doc """
  Subscribe the caller's PID to Manufacturer Specific Data updates sent as:
    {scanner,
     %{
       1 => <<1, 1, 3, 159, 210, 84>>,
       :name => "GVH5102_EED5",
       :time => ~U[2021-10-30 19:29:15.752998Z]
     }}
  """
  def subscribe(scanner) do
    GenServer.call(scanner, {:subscribe, true})
  end

  def unsubscribe(scanner) do
    GenServer.call(scanner, {:subscribe, false})
  end
end
