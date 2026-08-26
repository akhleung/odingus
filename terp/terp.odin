package terp

import "base:runtime"
import "core:math/ease"
import "core:math/linalg"

Terp :: struct($T: typeid) {
	value:      ^T,
	start:      T,
	end:        T,
	progress:   f32,
	duration:   f32,
	delay:      f32,
	easing:     ease.Ease,
	on_done:    proc(terp: ^Terp(T), data: rawptr),
	on_start:   proc(terp: ^Terp(T), data: rawptr),
	on_reverse: proc(terp: ^Terp(T), data: rawptr),
	on_repeat:  proc(terp: ^Terp(T), data: rawptr),
	data:       rawptr,
	is_started: bool,
	repeat:     bool,
	round_trip: bool,
	reversed:   bool,
}

Terps :: struct($T: typeid) {
	terps: [dynamic]Terp(T),
	index: map[^T]int,
}

reserve :: proc(terps: ^Terps($T), size: int) {
	runtime.reserve(&terps.terps, size)
	runtime.reserve(&terps.index, size)
}

to :: proc(
	terps: ^Terps($T),
	value: ^T,
	to: T,
	duration: f32,
	delay: f32 = 0,
	easing: ease.Ease = .Linear,
	repeat: bool = false,
	round_trip: bool = false,
	on_done: proc(terp: ^Terp(T), data: rawptr) = nil,
	on_start: proc(terp: ^Terp(T), data: rawptr) = nil,
	on_reverse: proc(terp: ^Terp(T), data: rawptr) = nil,
	on_repeat: proc(terp: ^Terp(T), data: rawptr) = nil,
	data: rawptr = nil,
) {
	i := len(terps.terps)
	append(
		&terps.terps,
		Terp(T) {
			value      = value,
			start      = value^,
			end        = to,
			progress   = 0,
			duration   = duration / (round_trip ? 2 : 1), // round-trip behaves like two terps, each taking half the time
			delay      = delay,
			easing     = easing,
			on_done    = on_done,
			on_start   = on_start,
			on_reverse = on_reverse,
			on_repeat  = on_repeat,
			data       = data,
			is_started = false,
			repeat     = repeat,
			round_trip = round_trip,
			reversed   = false,
		},
	)
	terps.index[value] = i
}

get :: proc(terps: ^Terps($T), value: ^T) -> (^Terp(T), bool) #no_bounds_check {
	if i, ok := terps.index[value]; ok {
		if terps.terps[i].value == value {
			return &terps.terps[i], true
		}
	}
	return nil, false
}

update :: proc(terps: ^Terps($T), dt: f32) #no_bounds_check {
	// reverse iteration so we can use unordered_remove without explicitly managing loop counters
	#reverse for &terp in terps.terps {
		dt := dt

		if (terp.delay > 0) {
			terp.delay -= dt
			if (terp.delay < 0) {
				// if dt was longer than the delay, reduce dt appropriately and start interpolating
				dt = -terp.delay
				terp.delay = 0
			} else {
				// else we either have remaining delay, or delay and dt matched exactly, so keep looping
				continue
			}
		}

		if !terp.is_started {
			terp.is_started = true
			if terp.on_start != nil {
				terp.on_start(&terp, terp.data)
			}
		}

		terp.progress += dt / terp.duration
		eased := ease.ease(terp.easing, terp.progress)
		terp.value^ = linalg.lerp(terp.start, terp.end, eased)

		// reached the end of this terp; need to decide whether to repeat, reverse, invoke callbacks, etc.
		if terp.progress >= 1 {

			terp.value^ = terp.end // don't overshoot

			// stop if this is a single one-way, or a single round-trip that's already been reversed
			if !terp.repeat && (!terp.round_trip || terp.reversed) {
				if terp.on_done != nil {
					terp.on_done(&terp, terp.data)
				}
				cancel(terps, terp.value)
				continue
			}

			if terp.round_trip {
				// if this is a repeating round-trip, then reverse and invoke callbacks
				terp.start, terp.end = terp.end, terp.start
				if terp.on_reverse != nil {
					terp.on_reverse(&terp, terp.data)
				}
				if terp.on_repeat != nil && terp.reversed {
					terp.on_repeat(&terp, terp.data)
				}
				terp.reversed = !terp.reversed
			} else if terp.on_repeat != nil {
				// else it's a repeating one-way, so just invoke the callback
				terp.on_repeat(&terp, terp.data)
			}

			// reset the progress after wrapping around or ping-ponging
			wraparound := terp.progress - 1
			terp.progress = wraparound
			// if dt was big enough to wrap around or ping-pong, then recalculate the value to reflect that
			if wraparound > 0 {
				eased := ease.ease(terp.easing, wraparound)
				terp.value^ = linalg.lerp(terp.start, terp.end, eased)
			}
		}
	}
}

is_started :: proc(terps: ^Terps($T), value: ^T) -> bool {
	if terp, ok := get(terps, value); ok {
		return terp.is_started
	}
	return false
}

is_done :: proc(terps: ^Terps($T), value: ^T) -> bool {
	return !(value in terps.index)
}

time_left :: proc(terps: ^Terps($T), value: ^T) -> f32 {
	if terp, ok := get(terps, value); ok {
		duration := terp.duration
		progress := terp.progress
		if terp.round_trip {
			duration *= 2
			progress /= 2
			progress += terp.reversed ? 0.5 : 0
		}
		return duration * (1 - progress)
	}
	return 0
}

cancel :: proc(terps: ^Terps($T), value: ^T) -> bool #no_bounds_check {
	if i, ok := terps.index[value]; ok {
		if terps.terps[i].value == value {
			delete_key(&terps.index, value)
			unordered_remove(&terps.terps, i) // last element gets moved into i
			if i < len(terps.terps) {
				// if we didn't just remove the last element, update the mapping with the element that was moved here
				terps.index[terps.terps[i].value] = i
			}
			return true
		}
	}
	return false
}

cancel_all :: proc(terps: ^Terps($T)) {
	clear(terps.terps)
	clear(terps.index)
}

destroy :: proc(terps: ^Terps($T)) {
	delete(terps.terps)
	delete(terps.index)
}
