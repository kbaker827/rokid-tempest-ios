# Tempest Glasses


> **🔵 Connectivity Update — May 2025**
> The glasses connection has been migrated from **raw TCP sockets** to
> **Bluetooth via the Rokid AI glasses SDK** (`pod 'RokidSDK' ~> 1.10.2`).
> No Wi-Fi port forwarding is needed. See **SDK Setup** below.

iOS app that pulls live weather data from your [WeatherFlow Tempest](https://tempestwx.com) station and streams it to Rokid AR glasses.

## How it works

```
Tempest Hub  ──UDP :50222──▶  iPhone (TempestGlasses)  ──Bluetooth/RokidSDK──▶ Rokid Glasses
                                     │
                              WeatherFlow REST API
                              (fallback / station info)
```

**No API key required for live data.** The Tempest Hub broadcasts UDP packets on port 50222 to every device on the same Wi-Fi network. The app picks them up instantly — sub-second latency for rapid wind updates every 3 seconds, full observations every minute.

## What's displayed on the glasses

Three selectable formats:

**Compact** (single line):
```
72°F  WSW 8 mph  UV 2.3  Dry
```

**Minimal**:
```
72°F  WSW 8 mph
```

**Multiline**:
```
72°F
WSW 8 mph
UV 2.3
Dry
⚡ 3 strikes (1h)
```

Lightning strike and rain-start events also trigger immediate alert messages pushed to the glasses.

## Glasses protocol (TCP :8088)

Each message is a JSON object followed by `\n`:

```json
{"type":"weather","text":"72°F  WSW 8 mph  UV 2.3  Dry"}
{"type":"obs","tempC":22.2,"tempF":72.0,"humidity":58.0,"windAvgMph":8.1,"windBearing":"WSW","uv":2.3,"rainMm":0.0,"pressureMb":1013.2,...}
{"type":"alert","text":"⚡ Lightning 12 km away"}
{"type":"alert","text":"🌧 Rain started"}
```

## Data sources

| Packet type | Source | Interval |
|-------------|--------|----------|
| `obs_st` | UDP broadcast | ~1 min |
| `rapid_wind` | UDP broadcast | 3 s |
| `evt_strike` | UDP broadcast | on event |
| `evt_precip` | UDP broadcast | on event |
| REST observations | WeatherFlow API | fallback when UDP silent >2 min |

## Metrics shown in app

- Temperature + feels like (heat index / wind chill)
- Humidity + dew point
- Wind: avg / gust / lull + direction compass + rapid wind
- UV index (color coded) + solar radiation + illuminance
- Station pressure
- Rain accumulation + precipitation type
- Lightning: count / avg distance (last hour)
- Station battery voltage

## SDK Setup

The glasses now connect over **Bluetooth via the Rokid AI glasses SDK** — no Wi-Fi port or TCP server needed.

The only thing left for each app is filling in the three credential constants (`kAppKey`, `kAppSecret`, `kAccessKey`) from [account.rokid.com/#/setting/prove](https://account.rokid.com/#/setting/prove), then running `pod install`.

1. **Get credentials** at <https://account.rokid.com/#/setting/prove> and paste them into the glasses Swift file:
   ```swift
   private let kAppKey    = "YOUR_APP_KEY"
   private let kAppSecret = "YOUR_APP_SECRET"
   private let kAccessKey = "YOUR_ACCESS_KEY"
   ```

2. **Install CocoaPods dependencies** from the repo root:
   ```bash
   pod install
   open *.xcworkspace   # always open the .xcworkspace, not .xcodeproj
   ```

3. *(Glasses now connect automatically over Bluetooth — no TCP port needed.)*

## Setup

1. Open `TempestGlasses.xcodeproj` in Xcode 15+.
2. Set your team in Signing & Capabilities.
3. Build and run on an iPhone (iOS 17+) **on the same Wi-Fi network as your Tempest Hub**.
4. Allow local network permission when prompted.
5. Data starts flowing immediately — no configuration needed.
6. **Optional**: In Settings, enter your WeatherFlow personal access token to enable REST fallback and station auto-discovery.
7. *(Glasses now connect automatically over Bluetooth — no TCP port needed.)*

## Requirements

- iOS 17.0+
- Xcode 15+
- WeatherFlow Tempest station on the same Wi-Fi
- No API key needed for live UDP data
