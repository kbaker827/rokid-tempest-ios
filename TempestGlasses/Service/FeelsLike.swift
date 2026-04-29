import Foundation

// Derived metrics matching WeatherFlow's formulas
enum FeelsLike {
    // Heat index (Steadman, °C) — valid when temp >= 27°C and RH >= 40%
    static func heatIndex(tempC: Double, rh: Double) -> Double {
        let t = tempC
        let h = rh
        return -8.784695 + 1.61139411 * t + 2.338549 * h
               - 0.14611605 * t * h - 0.01230809 * t * t
               - 0.01642482 * h * h + 0.00221173 * t * t * h
               + 0.00072546 * t * h * h - 0.00000358 * t * t * h * h
    }

    // Wind chill (°C) — valid when temp <= 10°C and wind >= 1.34 m/s
    static func windChill(tempC: Double, windMs: Double) -> Double {
        let v = pow(windMs * 3.6, 0.16)   // km/h then raised
        return 13.12 + 0.6215 * tempC - 11.37 * v + 0.3965 * tempC * v
    }

    static func feelsLike(tempC: Double, rh: Double, windMs: Double) -> Double {
        if tempC >= 27 && rh >= 40 {
            return heatIndex(tempC: tempC, rh: rh)
        } else if tempC <= 10 && windMs >= 1.34 {
            return windChill(tempC: tempC, windMs: windMs)
        }
        return tempC
    }

    // Dew point (Magnus formula)
    static func dewPoint(tempC: Double, rh: Double) -> Double {
        let a = 17.62, b = 243.12
        let alpha = log(rh / 100) + (a * tempC) / (b + tempC)
        return (b * alpha) / (a - alpha)
    }
}
