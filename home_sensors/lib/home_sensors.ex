defmodule HomeSensors do
  @moduledoc """
  Documentation for `HomeSensors`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> HomeSensors.hello()
      :world

  """
  def hello do
    :world
  end

  @cid_GVH5102 0x0001
  @cid_GVH5074 0xEC88
  @cids [@cid_GVH5102, @cid_GVH5074]

  alias HomeSensors.Scanner

  require Logger

  def subscribe do
    if Process.whereis(__MODULE__) do
      subscribe_now(self())
    else
      subscribe_later(self())
    end
  end

  defp subscribe_now(pid) do
    GenServer.cast(__MODULE__, {:subscribe, pid})
  end

  # Under the poncho, firmware depends on ui, so Ui.Application starts
  # before Firmware.Application starts this server. Handle the reboot
  # case where a browser is already looking at the page using this
  # data by subscribing later, instead of losing the subscription now.
  #
  # Another solution is to start a Registry early in ui and use it to
  # subscribe and dispatch updates.
  #
  defp subscribe_later(pid) do
    Logger.info("#{__MODULE__} subscribe later")

    spawn(fn ->
      Process.sleep(5000)
      subscribe_now(pid)
    end)
  end

  def set_zip_code(zip_code) when is_binary(zip_code) do
    GenServer.cast(__MODULE__, {:set_zip_code, zip_code})
  end

  @history_quick_interval_ms 1000 * 1
  @history_interval_ms 1000 * 60 * 2
  @get_aqi_interval_ms 1000 * 60 * 20

  defp schedule_history_quick() do
    Process.send_after(self(), :history_quick, @history_quick_interval_ms)
  end

  defp schedule_history() do
    Process.send_after(self(), :history, @history_interval_ms)
  end

  defp schedule_cleanup() do
    Process.send_after(self(), :cleanup, ms_to_next_day_at_utc_hour(8))
  end

  defp schedule_aqi() do
    Process.send_after(self(), :get_aqi, @get_aqi_interval_ms)
  end

  defp ms_to_next_day_at_utc_hour(hour) when is_integer(hour) do
    now = DateTime.utc_now()
    next = DateTime.new!(Date.add(now, 1), Time.new!(hour, 0, 0, 0))
    DateTime.diff(next, now, :millisecond)
  end

  def start_link(init_arg) when is_atom(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  use GenServer

  @impl GenServer
  def init(init_arg) do
    Logger.info("#{__MODULE__} init #{init_arg}")
    schedule_cleanup()
    scanner = init_arg
    cids = MapSet.new(@cids)
    Scanner.disable(scanner)
    Scanner.clear_devices(scanner)
    {:ok, _} = Scanner.accept_cids(scanner, cids)
    :ok = Scanner.subscribe(scanner)
    {:ok, %{scanner: scanner, subscribers: [], history: [], updates: []}}
  end

  @impl GenServer
  def handle_cast({:subscribe, pid}, state) do
    Logger.info("#{__MODULE__} subscribe #{inspect(pid)}")

    if subscribed?(state) do
      get_aqi(:aqi_quick)
    else
      HomeSensors.Scanner.enable(state.scanner)
      schedule_history_quick()
      get_aqi(:aqi)
    end

    send(pid, {:history, state.history})

    subscribers = [pid | state.subscribers]
    {:noreply, %{state | subscribers: subscribers}}
  end

  def handle_cast({:set_zip_code, zip_code}, state) do
    Logger.info("#{__MODULE__} zip code #{inspect(zip_code)}")

    env = Application.get_env(:ui, ZipCodeApi)

    if zip_code != env[:zip_code] do
      env = Keyword.put(env, :zip_code, zip_code)
      Application.put_env(:ui, ZipCodeApi, env)
      spawn(__MODULE__, :set_tz_ok, [2])
    end

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({module, %{} = device}, state) when module == state.scanner do
    # Logger.info("#{__MODULE__} #{inspect(device)}")
    {:noreply, %{state | updates: update(state.updates, device)}}
  end

  def handle_info({:aqi_quick, value}, state) do
    subscribers = alert_subscribers(state, {:aqi, value})
    state = %{state | subscribers: subscribers}
    {:noreply, state}
  end

  def handle_info({:aqi, _value} = event, state) do
    subscribers = alert_subscribers(state, event)
    if [] != subscribers, do: schedule_aqi()
    state = %{state | subscribers: subscribers}
    {:noreply, state}
  end

  def handle_info(:get_aqi, state) do
    if subscribed?(state), do: get_aqi(:aqi)
    {:noreply, state}
  end

  def handle_info(:history_quick, state) do
    if subscribed?(state) do
      count = devices_in_updates(state.updates)

      if count < device_count() do
        schedule_history_quick()
        {:noreply, state}
      else
        handle_info(:history, state)
      end
    else
      Scanner.disable(state.scanner)
      {:noreply, state}
    end
  end

  def handle_info(:history, state) do
    if subscribed?(state) do
      new_history =
        state.updates
        |> per_minute()
        |> per_minute_to_history()

      history = new_history ++ state.history
      subscribers = alert_subscribers(state, {:history, history})
      if [] == subscribers, do: Scanner.disable(state.scanner), else: schedule_history()
      state = %{state | subscribers: subscribers, history: history, updates: []}
      {:noreply, state}
    else
      Scanner.disable(state.scanner)
      {:noreply, state}
    end
  end

  def handle_info(:cleanup, state) do
    Logger.info("#{__MODULE__} cleanup")
    schedule_cleanup()
    {:noreply, %{state | history: []}}
  end

  def devices_in_updates(updates) when is_list(updates) do
    updates
    |> Enum.filter(fn d -> d.name in device_names() end)
    |> Enum.uniq_by(fn d -> d.name end)
    |> Enum.count()
  end

  defp subscribed?(state), do: [] != state.subscribers

  defp alert_subscribers(%{subscribers: subscribers}, event) do
    Enum.filter(subscribers, fn pid ->
      if Process.alive?(pid), do: send(pid, event)
    end)
  end

  def decode_data(device) do
    Enum.reduce(device, device, fn
      {k, v}, acc when is_integer(k) -> Map.delete(decode(k, v, acc), k)
      {:name, v}, acc -> %{acc | name: device_rename(v)}
      {_k, _v}, acc -> acc
    end)
  end

  # https://github.com/Home-Is-Where-You-Hang-Your-Hack/sensor.goveetemp_bt_hci
  # custom_components/govee_ble_hci/govee_advertisement.py
  # GVH5102 https://fccid.io/2AQA6-H5102 Thermo-Hygrometer
  defp decode(@cid_GVH5102, <<_::16, temhum::24, bat::8>>, device) do
    temp_c = temhum / 10000
    rh = rem(temhum, 1000) / 10
    Map.merge(device, %{temp_c: temp_c, rh: rh, battery: bat})
  end

  # https://github.com/wcbonner/GoveeBTTempLogger
  # goveebttemplogger.cpp
  # bool Govee_Temp::ReadMSG(const uint8_t * const data)
  # Govee_H5074 https://fccid.io/2AQA6-H5074 Thermo-Hygrometer
  defp decode(
         @cid_GVH5074,
         <<_::8, tem::signed-little-16, hum::little-16, bat::8, _::8>>,
         device
       ) do
    temp_c = tem / 100
    rh = hum / 100
    Map.merge(device, %{temp_c: temp_c, rh: rh, battery: bat})
  end

  defp decode(_k, _v, device) do
    device
  end

  defp update([], %{name: _} = device), do: [device]

  defp update([head | rest], %{name: _} = device) when head.name == device.name,
    do: [device | rest]

  defp update(updates, %{name: _} = device), do: [device | updates]

  # nameless case
  defp update(updates, _device), do: updates

  @doc """
  Convert:

    [ [
        %{
          1 => <<1, 1, 4, 17, 1, 88>>,
          :name => "GVH5102_EED5",
          :time => ~U[2022-11-04 17:06:47.797666Z]
        },
        %{
          60552 => <<0, 35, 9, 238, 19, 100, 2>>,
          :name => "Govee_H5074_F092",
          :time => ~U[2022-11-04 17:06:50.233368Z]
        }
      ],...
    ]

  To:

    [ [ "time", temp, dew, bat, temp, dew, bat],...]

  """
  def per_minute_to_history(updates_per_minute) do
    tz = Application.get_env(:ui, ZipCodeApi)[:time_zone] || "Etc/UTC"

    updates_per_minute
    |> Enum.map(fn row ->
      dt = List.first(row).time
      dt = DateTime.shift_zone!(dt, tz)

      [
        Calendar.strftime(dt, "%H:%M")
        | Enum.map(row, &decode_data/1)
          |> Enum.sort(fn a, b -> a.name < b.name end)
          |> Enum.flat_map(&device_summary/1)
      ]
    end)
  end

  defp device_summary(device) do
    dew_c = dewpoint(device.temp_c, device.rh)
    dew_f = Float.round(c_to_f(dew_c), 1)
    tem_f = Float.round(c_to_f(device.temp_c), 1)
    [tem_f, dew_f, device.battery]
  end

  # https://www.kgun9.com/weather/the-difference-between-dew-point-and-humidity
  # https://bmcnoldy.rsmas.miami.edu/Humidity.html
  # t˚C rh %
  defp dewpoint(t, rh) do
    243.04 * (Math.log(rh / 100) + 17.625 * t / (243.04 + t)) /
      (17.625 - Math.log(rh / 100) - 17.625 * t / (243.04 + t))
  end

  defp c_to_f(c) do
    c * 9 / 5 + 32
  end

  def per_minute(updates) do
    Enum.chunk_while(
      updates,
      per_minute_acc(),
      &per_minute_chunk/2,
      &per_minute_after/1
    )
  end

  defp per_minute_chunk(d, acc) do
    if acc.dt do
      # skipping to next minute

      if DateTime.diff(acc.dt, d.time, :minute) < 1 do
        {:cont, acc}
      else
        {:cont, acc.chunk, per_minute_acc(d)}
      end
    else
      if d.name in device_names() do
        per_minute_device(d, acc)
      else
        {:cont, acc}
      end
    end
  end

  defp per_minute_device(d, acc) do
    if d.name in acc.tally do
      {:cont, acc}
    else
      tally = MapSet.put(acc.tally, d.name)
      chunk = [d | acc.chunk]
      count = acc.count + 1

      if count == device_count() do
        {:cont, %{acc | chunk: chunk, dt: d.time}}
      else
        {:cont, %{acc | tally: tally, chunk: chunk, count: count}}
      end
    end
  end

  defp per_minute_after(acc) do
    if acc.dt do
      {:cont, acc.chunk, acc}
    else
      {:cont, acc}
    end
  end

  defp per_minute_acc(), do: %{tally: MapSet.new(), dt: nil, chunk: [], count: 0}

  defp per_minute_acc(d) do
    if d.name in device_names() do
      %{tally: MapSet.new([d.name]), dt: nil, chunk: [d], count: 1}
    else
      per_minute_acc()
    end
  end

  @device_to_user_names %{
    "GVH5102_EED5" => "inside",
    "Govee_H5074_F092" => "outside"
  }

  @device_count Enum.count(@device_to_user_names)

  def device_count, do: @device_count

  defp device_to_user_names, do: @device_to_user_names
  defp device_names, do: MapSet.new(Map.keys(@device_to_user_names))

  defp device_rename(name) do
    Map.get(device_to_user_names(), name, "")
  end

  defp get_aqi(key) do
    # Logger.info("#{__MODULE__} get_aqi #{key}")

    pid = self()
    env = Application.get_env(:ui, AirNowApi)
    api_key = env[:api_key]
    env = Application.get_env(:ui, ZipCodeApi)
    zip_code = env[:zip_code]

    spawn(fn ->
      aqi = AirNowApi.get_summary(zip_code, api_key)
      send(pid, {key, aqi})
    end)
  end

  def set_tz_ok(seconds) do
    limit_ms = 1000 * 60 * 60
    ms = 1000 * seconds

    if set_tz() != :ok do
      Process.sleep(ms)
      set_tz_ok(min(seconds * 2, limit_ms))
    end
  end

  defp set_tz do
    with env <- Application.get_env(:ui, ZipCodeApi),
         {:ok, result} <- ZipCodeApi.zip_to_loc(env[:app_key], env[:zip_code]),
         tz <- result["timezone"]["timezone_identifier"] do
      env = Keyword.put(env, :time_zone, tz)
      Application.put_env(:ui, ZipCodeApi, env)
    else
      error ->
        require Logger
        Logger.info("#{__MODULE__} set_tz #{inspect(error)}")
        error
    end
  end
end
