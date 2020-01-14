Adds Activities from Events to your Withings Account

This agent will create new activities in your Withings account from
events. This is useful if you own multiple devices (e.g., a Fitbit and
a Withings) and want to consolidate your calories consumption into one.

Withings has an OAUTHv2 API but it only allows to read activities. This
agent simulates Withings' app to add activities using their private one.
This is why it requires username and password. The password is not stored
in plain text.

## Example Event
The agent expects an event with the following fields
```ruby
  {
    'activity_name'   => 'Walking',               # defaults to `other`
    'timezone'        => 'America/Los_Angeles',   # o/w uses `options`
    'start_time'      => 1578401100,              # epoch
    'end_time'        => 1578404700,              # epoch
    'calories'        => 500,                     # kcal
    'distance'        => 1000,                    # in meters
    'intensity'       => 40,                      # defaults to 50
  }
```

If `end_time` is not available one can specify `duration` in seconds,
  similarly, if `subcategory` is known it can be specified instead of
  `activity_name`.

Valid `activity_name` are walking (1), running (2), hiking (3),
  bicycling (6), swimming (7), tennis (12), weights (16), class (17),
  elliptical (18), basketball (20), soccer (21), volleyball (24) and
  yoga (28).
