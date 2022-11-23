defmodule ZipCodeApi do
  @moduledoc """
  https://www.zipcodeapi.com/API
  """

  @doc """
  https://www.zipcodeapi.com/API#zipToLoc
  """
  @spec zip_to_loc(String.t(), String.t()) :: {:ok, map()} | {:error, any}

  def zip_to_loc(api_key, zip_code) do
    url = "https://www.zipcodeapi.com/rest/#{api_key}/info.json/#{zip_code}/degrees"

    case HTTPoison.get(url) do
      {:ok, %{status_code: 200, body: body}} -> Jason.decode(body)
      {:error, _} = error -> error
      error -> {:error, error}
    end
  end
end
