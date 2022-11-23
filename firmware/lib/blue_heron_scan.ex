defmodule BlueHeronScan do
  @moduledoc ~S"""
  A scanner to collect Manufacturer Specific Data from AdvertisingReport packets.

  A useful reference:
  [Overview of BLE device identification](https://reelyactive.github.io/ble-identifier-reference.html)

  The Assigned Numbers Document has the latest company identifiers list:
  https://www.bluetooth.com/specifications/assigned-numbers

  Tested with:
    - [Raspberry Pi Model Zero W](https://github.com/nerves-project/nerves_system_rpi0)
      - /dev/ttyS0 is the BLE controller transport interface
    - [BlueHeronTransportUART](https://github.com/blue-heron/blue_heron_transport_uart)
    - [Govee H5102](https://fccid.io/2AQA6-H5102) Thermo-Hygrometer
    - [Govee H5074](https://fccid.io/2AQA6-H5074) Thermo-Hygrometer
    - Random devices from neighbors and passing cars.😉

  ## Examples

      iex> {:ok, pid} = BlueHeronScan.start_link(%{device: "ttyS0"})
      {:ok, #PID<0.4022.0>}
      iex> BlueHeronScan.enable
      :ok
      iex> BlueHeronScan.devices
      {:ok,
       %{
         181149778439893 => %{
           1 => <<1, 1, 3, 159, 210, 84>>,
           :name => "GVH5102_EED5",
           :time => ~U[2021-10-30 19:29:15.752998Z]
         },
         181149781445015 => %{
           name: "ihoment_H6182_C997",
           time: ~U[2021-10-30 19:29:10.815584Z]
         },
         210003231250023 => %{
           name: "ELK-BLEDOM ",
           time: ~U[2021-10-30 19:29:16.227270Z]
         },
         246390811914386 => %{
           60552 => <<0, 192, 5, 46, 30, 100, 2>>,
           :name => "Govee_H5074_F092",
           :time => ~U[2021-10-30 19:29:15.792268Z]
         }
       }}
      iex> BlueHeronScan.disable
      :ok
      iex> BlueHeronScan.clear_devices
      :ok
      iex> BlueHeronScan.devices
      {:ok, %{}}
  """

  use GenServer
  require Logger

  alias BlueHeron.HCI.Command.{
    ControllerAndBaseband.WriteLocalName,
    LEController.SetScanEnable
  }

  alias BlueHeron.HCI.Event.{
    LEMeta.AdvertisingReport,
    LEMeta.AdvertisingReport.Device
  }

  @init_commands [%WriteLocalName{name: "BlueHeronScan"}]

  @default_uart_config %{
    device: "ttyACM0",
    uart_opts: [speed: 115_200],
    init_commands: @init_commands
  }

  @default_usb_config %{
    vid: 0x0BDA,
    pid: 0xB82C,
    init_commands: @init_commands
  }

  @doc """
  Start a linked connection to the Bluetooth module and enable active scanning.

  ## UART

      iex> {:ok, pid} = BlueHeronScan.start_link(%{device: "ttyS0"})
      {:ok, #PID<0.111.0>}

  ## USB

      iex> {:ok, pid} = BlueHeronScan.start_link(%{vid: 0x0BDA, pid: 0xB82C})
      {:ok, #PID<0.111.0>}
  """
  def start_link(config) when is_map(config) do
    config =
      if config[:device] do
        struct(BlueHeronTransportUART, Map.merge(@default_uart_config, config))
      else
        struct(BlueHeronTransportUSB, Map.merge(@default_usb_config, config))
      end

    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  @doc """
  Enable BLE scanning.

  Returns `:ok` or `{:error, :not_working}` if uninitialized.
  """
  def enable do
    GenServer.call(__MODULE__, :scan_enable)
  end

  @doc """
  Disable BLE scanning.

  Returns `:ok`.
  """
  def disable do
    GenServer.call(__MODULE__, :scan_disable)
  end

  @doc """
  Get devices.

      iex> BlueHeronScan.devices()
      {:ok, %{}}
  """
  def devices do
    GenServer.call(__MODULE__, :devices)
  end

  @doc """
  Clear devices from the state.

      iex> BlueHeronScan.clear_devices()
      :ok
  """
  def clear_devices do
    GenServer.call(__MODULE__, :clear_devices)
  end

  def accept_cids(cids \\ nil) do
    GenServer.call(__MODULE__, {:accept_cids, cids})
  end

  @doc """
  Get or set the company IDs to ignore.

  https://www.bluetooth.com/specifications/assigned-numbers

  Apple and Microsoft beacons, 76 & 6, are noisy.

  ## Examples

      iex> BlueHeronScan.ignore_cids()
      {:ok, [6, 76]}
      iex> BlueHeronScan.ignore_cids([6, 76, 117])
      {:ok, [6, 76, 117]}
  """
  def ignore_cids(cids \\ nil) do
    GenServer.call(__MODULE__, {:ignore_cids, cids})
  end

  @doc """
  Subscribe the caller's PID to Manufacturer Specific Data updates sent as:
  """
  def subscribe do
    GenServer.call(__MODULE__, {:subscribe, true})
  end

  def unsubscribe do
    GenServer.call(__MODULE__, {:subscribe, false})
  end

  @impl GenServer
  def init(config) do
    # Create a context for BlueHeron to operate with.
    {:ok, ctx} = BlueHeron.transport(config)

    # Subscribe to HCI and ACL events.
    BlueHeron.add_event_handler(ctx)

    {:ok,
     %{
       ctx: ctx,
       working: false,
       devices: %{},
       accept_cids: nil,
       ignore_cids: [6, 76],
       subscribers: []
     }}
  end

  # Sent when a transport connection is established.
  @impl GenServer
  def handle_info({:BLUETOOTH_EVENT_STATE, :HCI_STATE_WORKING}, state) do
    state = %{state | working: true}
    Logger.info("#{__MODULE__} working")
    {:noreply, state}
  end

  # Scan AdvertisingReport packets.
  def handle_info(
        {:HCI_EVENT_PACKET, %AdvertisingReport{devices: devices}},
        state
      ) do
    {:noreply, Enum.reduce(devices, state, &scan_device/2)}
  end

  # Ignore other HCI Events.
  def handle_info({:HCI_EVENT_PACKET, _val}, state) do
    # Logger.debug("#{__MODULE__} ignore HCI Event #{inspect(val)}")
    {:noreply, state}
  end

  @impl GenServer
  def handle_call(:devices, _from, state) do
    {:reply, {:ok, state.devices}, state}
  end

  def handle_call(:clear_devices, _from, state) do
    {:reply, :ok, %{state | devices: %{}}}
  end

  def handle_call({:accept_cids, cids}, _from, state) do
    cond do
      cids == nil ->
        {:reply, {:ok, state.accept_cids}, state}

      Enumerable.impl_for(cids) ->
        cids = if Enum.count(cids) == 0, do: nil, else: cids
        {:reply, {:ok, cids}, %{state | accept_cids: cids}}

      true ->
        {:reply, {:error, :not_enumerable}, state}
    end
  end

  def handle_call({:ignore_cids, cids}, _from, state) do
    cond do
      cids == nil ->
        {:reply, {:ok, state.ignore_cids}, state}

      Enumerable.impl_for(cids) ->
        cids = if Enum.count(cids) == 0, do: nil, else: cids
        {:reply, {:ok, cids}, %{state | ignore_cids: cids}}

      true ->
        {:reply, {:error, :not_enumerable}, state}
    end
  end

  def handle_call({:subscribe, true}, {pid, _tag}, state) do
    {:reply, :ok, %{state | subscribers: [pid | state.subscribers]}}
  end

  def handle_call({:subscribe, false}, {pid, _tag}, state) do
    subscribers = Enum.reject(state.subscribers, &(&1 == pid))
    {:reply, :ok, %{state | subscribers: subscribers}}
  end

  def handle_call(:scan_enable, _from, state) do
    {:reply, scan(state, true), state}
  end

  def handle_call(:scan_disable, _from, state) do
    scan(state, false)
    {:reply, :ok, state}
  end

  defp scan(%{working: false}, _enable) do
    {:error, :not_working}
  end

  defp scan(%{ctx: ctx = %BlueHeron.Context{}}, enable) do
    BlueHeron.hci_command(ctx, %SetScanEnable{le_scan_enable: enable})
    status = if(enable, do: "enabled", else: "disabled")
    Logger.info("#{__MODULE__} #{status} scanning")
  end

  defp scan_device(device, state) do
    case device do
      %Device{address: addr, data: data} ->
        Enum.reduce(data, state, fn e, acc ->
          cond do
            is_local_name?(e) -> store_local_name(acc, addr, e)
            is_mfg_data?(e) -> store_mfg_data(acc, addr, e)
            true -> acc
          end
        end)

      _ ->
        state
    end
  end

  defp is_local_name?(val) do
    is_binary(val) && String.starts_with?(val, "\t") && String.valid?(val)
  end

  defp is_mfg_data?(val) do
    is_tuple(val) && elem(val, 0) == "Manufacturer Specific Data"
  end

  defp store_local_name(state, addr, "\t" <> name) do
    device = Map.get(state.devices, addr, %{})
    device = Map.merge(device, %{name: name, time: DateTime.utc_now()})
    %{state | devices: Map.put(state.devices, addr, device)}
  end

  defp store_mfg_data(state, addr, dt) do
    with {_, mfg_data} <- dt,
         <<cid::little-16, sdata::binary>> <- mfg_data,
         true <- save_cid?(cid, state) do
      device = Map.get(state.devices, addr, %{})
      device = Map.merge(device, %{cid => sdata, time: DateTime.utc_now()})
      devices = Map.put(state.devices, addr, device)
      subscribers = alert_subscribers(state.subscribers, device)
      %{state | subscribers: subscribers, devices: devices}
    else
      _ -> state
    end
  end

  defp save_cid?(cid, state) do
    cond do
      state.accept_cids -> cid in state.accept_cids
      state.ignore_cids -> cid not in state.ignore_cids
      true -> true
    end
  end

  defp alert_subscribers(subscribers, device) do
    Enum.filter(subscribers, fn pid ->
      if Process.alive?(pid), do: send(pid, {__MODULE__, device})
    end)
  end
end
