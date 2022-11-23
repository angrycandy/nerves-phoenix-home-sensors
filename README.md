# Nerves Phoenix Home Sensors

* The base commit is [Hello Phoenix] at [commit] from [Nerves Example].
* http://localhost:4000/sensors works with `cd ui; mix phx.server`
* Use https://docs.airnowapi.org by ZIP code for https://www.airnow.gov data.
* Use https://www.zipcodeapi.com/API#zipToLoc for the ZIP code's time zone.
* Works with `MIX_TARGET=rpi0` and [GVH5102], [GVH5074] Thermo-Hygrometers.

[Nerves Example]: https://github.com/nerves-project/nerves_examples
[Hello Phoenix]: https://github.com/nerves-project/nerves_examples/tree/main/hello_phoenix
[commit]: https://github.com/nerves-project/nerves_examples/commit/c2459db4a68908e5caf1066d99ab1e36bb66a454
[GVH5102]: https://fccid.io/2AQA6-H5102
[GVH5074]: https://fccid.io/2AQA6-H5074

## Hello Phoenix Introduction

This example demonstrates a basic poncho project for deploying a [Phoenix
Framework]-based application to a Nerves device. A "poncho project" is similar
to an umbrella project except that it's actually multiple separate-but-related
Elixir apps that use `path` dependencies instead of `in_umbrella` dependencies.
You can read more about the motivations behind this concept on the
embedded-elixir blog post about [Poncho Projects]. The steps for creating this
example source are in [User Interfaces].

## Hardware

This example serves a Phoenix-based web page over the network. The steps below
assume you are using a Raspberry Pi Zero, which allows you to connect a single
USB cable to the port marked "USB" to get both network and serial console
access to the device. By default, this example will use the virtual Ethernet
interface provided by the USB cable, assign an IP address automatically, and
make it discoverable using mDNS (Bonjour). For more information about how to
configure the network settings for your environment, including WiFi settings,
see the [`vintage_net` documentation](https://hexdocs.pm/vintage_net/).

## How to Use this Repository

1. Connect your target hardware to your host computer or network as described
   above
2. Prepare your Phoenix project to build JavaScript and CSS assets:

    ```bash
    cd ui

    # This needs to be repeated when you change dependencies for the UI.
    mix deps.get
    ```

3. Build your assets and prepare them for deployment to the firmware:

    ```bash
    # Still in ui directory from the prior step.
    # This needs to be repeated when you change JS or CSS files.
    mix assets.deploy
    ```

4. Change to the `firmware` app directory

    ```bash
    cd ../firmware
    ```

5. Specify your target and other environment variables as needed in mix-export:

    ```bash
    . mix-export

    #   export MIX_TARGET=rpi0
    #   export SECRET_KEY_BASE=...
    #   export AIRNOWAPI_API_KEY=...
    #   export ZIPCODEAPI_APP_KEY=...
    #   export NERVES_NETWORK_SSID=your_wifi_name
    #   export NERVES_NETWORK_PSK=your_wifi_password
    ```

6. Get dependencies, build firmware, and burn it to an SD card:

    ```bash
    mix deps.get
    mix firmware
    mix firmware.burn
    ```

7. Insert the SD card into your target board and connect the USB cable or otherwise power it on
8. Wait for it to finish booting (5-10 seconds)
9. Open a browser window on your host computer to `http://nerves.local/`
10. You should see a "Welcome to Phoenix!" page

[Phoenix Framework]: http://www.phoenixframework.org/
[Poncho Projects]: http://embedded-elixir.com/post/2017-05-19-poncho-projects/
[User Interfaces]: https://hexdocs.pm/nerves/user-interfaces.html

## Learn More

* Official docs: https://hexdocs.pm/nerves/getting-started.html
* Official website: https://nerves-project.org/
* Discussion Slack elixir-lang #nerves ([Invite](https://elixir-slackin.herokuapp.com/))
* Source: https://github.com/nerves-project/nerves
