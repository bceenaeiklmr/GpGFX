; Script     Time.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       29.08.2026
; Version    1.0.0

#Requires AutoHotkey v2

/**
 * GpGFX time, duration and animation easing
 *
 * Provides microsecond-level QueryPerformanceCounter timing, duration helpers,
 * responsive non-blocking delays, and standard animation easing interpolation curves.
 */
class Time {

    static Frequency := (DllCall("QueryPerformanceFrequency", "int64*", &freq:=0), freq)

    /**
     * Gets the current high-precision timestamp in fractional seconds.
     *
     * @returns {Float} High-precision timestamp in seconds
     *
     * @example
     * t0 := Time.Now()
     * ; ... do work ...
     * elapsedMs := (Time.Now() - t0) * 1000.0
     */
    static Now() {
        local count := 0
        return (DllCall("QueryPerformanceCounter", "int64*", &count:=0), count / this.Frequency)
    }

    /**
     * Gets elapsed time in milliseconds since a previous timestamp.
     *
     * @param {Float} start Starting timestamp from Time.Now()
     * @returns {Float} Milliseconds elapsed
     *
     * @example
     * start := Time.Now()
     * ; ... perform rendering ...
     * dtMs := Time.Since(start)
     */
    static Since(start) {
        return (this.Now() - start) * 1000.0
    }

    /**
     * Returns raw QueryPerformanceCounter tick count.
     *
     * @returns {Integer} Raw 64-bit QPC tick count
     */
    static Qpc() {
        local count := 0
        DllCall("QueryPerformanceCounter", "int64*", &count:=0)
        return count
    }

    ; Duration conversions
    static FromSeconds(s) => Float(s) * 1000.0
    static FromMilliseconds(ms) => Float(ms)
    static FromMinutes(m) => Float(m) * 60000.0
    static FromHours(h) => Float(h) * 3600000.0

    /**
     * Delays execution for a specified duration in milliseconds while keeping the OS message loop responsive.
     *
     * @param {Float} ms Milliseconds to wait
     * @returns {void}
     *
     * @example
     * Time.Delay(16.67) ; Delay 1 frame duration
     */
    static Delay(ms) {
        local start := this.Now()
        local targetSec := ms / 1000.0
        while ((this.Now() - start) < targetSec) {
            Sleep(0)
        }
    }

    /**
     * Standard animation easing interpolation curves (0.0 -> 1.0).
     */
    class Ease {
        static Linear(t) => Max(0.0, Min(1.0, Float(t)))
        static InQuad(t) => (t := Max(0.0, Min(1.0, Float(t)))) * t
        static OutQuad(t) => (t := Max(0.0, Min(1.0, Float(t)))) * (2.0 - t)
        
        static InOutQuad(t) {
            t := Max(0.0, Min(1.0, Float(t)))
            return (t < 0.5) ? (2.0 * t * t) : (-1.0 + (4.0 - 2.0 * t) * t)
        }
        
        static InCubic(t) => (t := Max(0.0, Min(1.0, Float(t)))) * t * t
        
        static OutCubic(t) {
            t := Max(0.0, Min(1.0, Float(t))) - 1.0
            return t * t * t + 1.0
        }
        
        static InOutCubic(t) {
            t := Max(0.0, Min(1.0, Float(t)))
            return (t < 0.5) ? (4.0 * t * t * t) : ((t - 1.0) * (2.0 * t - 2.0) * (2.0 * t - 2.0) + 1.0)
        }
        
        static SmoothStep(t) {
            t := Max(0.0, Min(1.0, Float(t)))
            return t * t * (3.0 - 2.0 * t)
        }

        static Sine(t) {
            static PI := 3.141592653589793
            t := Max(0.0, Min(1.0, Float(t)))
            return (1.0 - Cos(t * PI)) / 2.0
        }
    }
}
