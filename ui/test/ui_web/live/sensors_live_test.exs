defmodule UiWeb.SensorsLiveTest do
  use UiWeb.ConnCase

  import Phoenix.LiveViewTest

  test "disconnected and connected render", %{conn: conn} do
    {:ok, sensors_live, disconnected_html} = live(conn, "/sensors")
    assert disconnected_html =~ "Dew Pt"
    assert render(sensors_live) =~ "Dew Pt"
  end
end
