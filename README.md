# Jinja2Config

## About

Watches for ``*.yaml.jinja`` files in your Home Assistant config directory and compiles them
to ``.yaml`` files.

This is useful to simplify complex configuration with repeated components.

If you find this addon useful, please consider supporting the development of this and my other addons and integrations by buying me a coffee

<a href="https://www.buymeacoffee.com/tonyroberts" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" style="height: 60px !important;width: 217px !important;" ></a>

## Installation

1. Go to ``Settings`` -> ``Add-ons`` and click the "Add-on Store" button.

2. Select ``Repositories`` using the three dots menu at the top of the page.

3. Add the URL for this github repo to add it.

4. Find the ``jinja2config`` addon now the repository has been added and install it.

## Example

I set up smart thermostats to control the underfloor heating for multiple rooms, requiring a certain amount of similar config per room. Using a template the amount of hand written yaml is greatly reduced, making it easier to manage and change as needed.

The following is a sample from my heating system, setting up the climate entities for just two rooms. The complete set up involves more rooms, sensors, switches and, automations. Using templates adding more rooms doesn't require any repeated code.

Any changes to the template result in the yaml file being regenerated automatically. Any errors are written to an error file alongside the template.

```
{% set rooms = [
    {
        "name": "Living Room",
        "id_prefix": "living_room",
        "kp": 100,
        "ki": 0.01,
        "kd": 2500
    },
    {
        "name": "Study",
        "id_prefix": "study",
        "kp": 100,
        "ki": 0.001,
        "kd": 1000
    }
] %}

{% set presets = {
    "min": 7,
    "max": 25,
    "away": 7,
    "eco": 17,
    "sleep": 17,
    "comfort": 19,
    "boost": 21
} %}

climate:
  {% for room in rooms %}
  - platform: smart_thermostat
    name: {{ room.name }} Smart Thermostat
    unique_id: {{ room.id_prefix }}_smart_thermostat
    heater: switch.{{ room.id_prefix }}_heating
    target_sensor: sensor.{{ room.id_prefix }}_temperature
    ac_mode: False
    kp: {{ room.kp }}
    ki: {{ room.ki }}
    kd: {{ room.kd }}
    keep_alive: 00:01:00
    pwm: 00:25:00
    min_cycle_duration: 00:5:00
    {%- for preset in presets %}
    {{ preset }}_temp: {{ presets[preset] }}
    {%- endfor %}
    target_temp: {{ presets["away"] }}
    debug: true
  {% endfor %}
```

## Credits

https://gist.github.com/ndbroadbent/7c80201aca3b4025b943440605f48382
