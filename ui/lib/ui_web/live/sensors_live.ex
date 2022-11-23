defmodule UiWeb.SensorsLive do
  use UiWeb, :live_view

  @impl Phoenix.LiveView
  def mount(params, _session, socket) do
    socket =
      socket
      |> assign(page_title: "Sensors")
      |> assign(history: [])
      |> assign(aqi: "AQI...")

    if connected?(socket) do
      HomeSensors.subscribe()
    else
      zip = Map.get(params, "zip")
      if zip, do: HomeSensors.set_zip_code(zip)
    end

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({key, value}, socket), do: {:noreply, assign(socket, key, value)}
end
