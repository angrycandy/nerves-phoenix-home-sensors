defmodule HomeSensorsTest do
  use ExUnit.Case, async: true
  doctest HomeSensors

  test "per minute", %{update: updates, updates_per_minute: updates_per_minute} do
    assert HomeSensors.per_minute([]) == []
    assert HomeSensors.per_minute([List.first(updates)]) == []
    assert HomeSensors.per_minute(updates) == updates_per_minute
  end

  test "decode", %{decoded: decoded, updates_per_minute: updates_per_minute} do
    assert decoded == List.first(updates_per_minute) |> Enum.map(&HomeSensors.decode_data/1)
  end

  test "history", %{history: history, updates_per_minute: updates_per_minute} do
    assert history == HomeSensors.per_minute_to_history(updates_per_minute)
  end

  test "devices_in_updates", %{update: updates} do
    assert HomeSensors.devices_in_updates(updates) == HomeSensors.device_count()
  end

  setup_all do
    updates = [
      %{
        60552 => <<0, 35, 9, 238, 19, 100, 2>>,
        :name => "Govee_H5074_F092",
        :time => ~U[2022-11-04 17:06:50.233368Z]
      },
      %{
        1 => <<1, 1, 4, 17, 1, 88>>,
        :name => "GVH5102_EED5",
        :time => ~U[2022-11-04 17:06:47.797666Z]
      },
      %{
        60552 => <<0, 35, 9, 147, 19, 100, 2>>,
        :name => "Govee_H5074_F092",
        :time => ~U[2022-11-04 17:06:30.242301Z]
      },
      %{
        60552 => <<0, 30, 9, 177, 19, 100, 2>>,
        :name => "Govee_H5074_F092",
        :time => ~U[2022-11-04 17:06:12.237115Z]
      },
      %{
        1 => <<1, 1, 4, 17, 1, 88>>,
        :name => "GVH5102_EED5",
        :time => ~U[2022-11-04 17:05:44.935016Z]
      },
      %{
        60552 => <<0, 26, 9, 0, 20, 100, 2>>,
        :name => "Govee_H5074_F092",
        :time => ~U[2022-11-04 17:04:12.248279Z]
      },
      %{
        1 => <<1, 1, 4, 17, 0, 88>>,
        :name => "GVH5102_EED5",
        :time => ~U[2022-11-04 17:04:11.669456Z]
      },
      %{
        60552 => <<0, 27, 9, 222, 19, 100, 2>>,
        :name => "Govee_H5074_F092",
        :time => ~U[2022-11-04 17:04:00.250560Z]
      },
      %{
        1 => <<1, 1, 4, 17, 0, 88>>,
        :name => "GVH5102_EED5",
        :time => ~U[2022-11-04 17:03:53.450192Z]
      }
    ]

    updates_per_minute = [
      [
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
      ],
      [
        %{
          60552 => <<0, 26, 9, 0, 20, 100, 2>>,
          :name => "Govee_H5074_F092",
          :time => ~U[2022-11-04 17:04:12.248279Z]
        },
        %{
          1 => <<1, 1, 4, 17, 1, 88>>,
          :name => "GVH5102_EED5",
          :time => ~U[2022-11-04 17:05:44.935016Z]
        }
      ]
    ]

    decoded = [
      %{
        battery: 88,
        name: "inside",
        rh: 49.7,
        temp_c: 26.6497,
        time: ~U[2022-11-04 17:06:47.797666Z]
      },
      %{
        battery: 100,
        name: "outside",
        rh: 51.02,
        temp_c: 23.39,
        time: ~U[2022-11-04 17:06:50.233368Z]
      }
    ]

    history = HomeSensors.Dev.history_test()

    [decoded: decoded, history: history, update: updates, updates_per_minute: updates_per_minute]
  end
end
