defmodule AirNowApi do
  require Logger

  def get(zip_code, api_key) do
    url =
      "https://www.airnowapi.org/aq/observation/zipCode/current/?format=application/json&zipCode=#{zip_code}&distance=10&API_KEY=#{api_key}"

    with {:ok, %{status_code: 200, body: body}} <- HTTPoison.get(url),
         {:ok, _} = decoded <- Jason.decode(body) do
      decoded
    else
      error ->
        Logger.info("#{__MODULE__} #{inspect(error)}")
        error
    end
  end

  def get_summary(zip_code, api_key) do
    result = get(zip_code, api_key)

    case result do
      {:ok, [h | _] = data} ->
        time_loc =
          ". At #{h["HourObserved"]}:00 in #{h["ReportingArea"]}, #{h["StateCode"]} #{zip_code}."

        stats =
          data
          |> Enum.sort(fn a, b -> a["AQI"] >= b["AQI"] end)
          |> Enum.map(fn e ->
            "AQI #{e["AQI"]} #{e["ParameterName"]} is #{e["Category"]["Name"]}"
          end)
          |> Enum.join(". ")

        stats <> time_loc

      _ ->
        "N/A"
    end
  end
end
