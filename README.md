# Activity Hub

Flutter PSP/XMB activity hub with JJTunes and SkyZine, an iPad-inspired weather activity.

## Run

Install Flutter, then run:

```sh
flutter pub get
flutter run
```

SkyZine (Activity 2) uses the configured OpenWeather key for current conditions and the
5-day / 3-hour forecast. It shows five upcoming days, rain chance, rain amount,
humidity, wind, feels-like temperature, and local sunrise/sunset times.

Daily summaries combine the available three-hour readings: low/high are sampled
temperatures, rain chance is the highest interval probability, and rain amount
is the sum of forecast rain volumes. A day with fewer than eight readings is
marked as partial. Current rainfall covers the past hour.

The sky responds to conditions and day/night: sun, moon and stars, clouds, rain,
snow, or mist. Motion stops when the device requests reduced animation.
