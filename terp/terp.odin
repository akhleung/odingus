package terp

import "core:math/ease"
import "core:math/linalg"

Playback :: enum {
	Forward_Once,
	Forward_Loop,
	Ping_Pong_Once,
	Ping_Pong_Loop,
}

Terp :: struct($T: typeid) {
	value:      ^T,
	start:      T,
	end:        T,
	progress:   f32,
	duration:   f32,
	delay:      f32,
	easing:     ease.Ease,
	playback:   Playback,
	on_done:    proc(terp: ^Terp(T), user_data: rawptr),
	on_start:   proc(terp: ^Terp(T), user_data: rawptr),
	user_data:  rawptr,
	is_started: bool,
}

Terps :: struct($T: typeid) {
	terps: [dynamic]Terp(T),
	index: map[^T]int,
}

terp_reserve :: proc(terps: ^Terps($T), size: int) {
	reserve(&terps.terps, size)
	reserve(&terps.index, size)
}

terp_to :: proc(
	terps: ^Terps($T),
	value: ^T,
	to: T,
	duration: f32,
	delay: f32 = 0,
	easing: ease.Ease = .Linear,
	playback: Playback = .Forward_Once,
	on_done: proc(terp: ^Terp(T), user_data: rawptr) = nil,
	on_start: proc(terp: ^Terp(T), user_data: rawptr) = nil,
	user_data: rawptr = nil,
) {
	i := len(terps.terps)
	append(
		&terps.terps,
		Terp(T) {
			value = value,
			start = value^,
			end = to,
			progress = 0,
			duration = duration,
			delay = delay,
			easing = easing,
			playback = playback,
			on_done = on_done,
			on_start = on_start,
			user_data = user_data,
			is_started = false,
		},
	)
	terps.index[value] = i
}

terp_get :: proc(terps: ^Terps($T), value: ^T) -> (^Terp(T), bool) {
	if i, ok := terps.index[value]; ok {
		if terps.terps[i].value == value {
			return &terps.terps[i], true
		}
	}
	return nil, false
}

terp_update :: proc(terps: ^Terps($T), dt: f32) {
	for i := 0; i < len(terps.terps);  /* increment manually since we might remove elements */{

		dt := dt
		terp := &terps.terps[i]

		if (terp.delay > 0) {
			terp.delay -= dt
			if (terp.delay < 0) {
				// if dt was longer than the delay, reduce dt appropriately and start interpolating
				dt = -terp.delay
				terp.delay = 0
			} else {
				// else we either have remaining delay, or delay and dt matched exactly, so keep looping
				i += 1
				continue
			}
		}

		if !terp.is_started {
			terp.is_started = true
			if terp.on_start != nil {
				terp.on_start(terp, terp.user_data)
			}
		}

		terp.progress += dt / terp.duration
		eased := ease.ease(terp.easing, terp.progress)
		terp.value^ = linalg.lerp(terp.start, terp.end, eased)

		if terp.progress >= 1 { 	// TODO: handle excess progress for looping and bouncing
			terp.value^ = terp.end
			if terp.on_done != nil {
				terp.on_done(terp, terp.user_data)
			}
			terp_cancel(terps, terp.value)
		} else {
			i += 1
		}
	}
}

terp_is_started :: proc(terps: ^Terps($T), value: ^T) -> bool {
	if terp, ok := terp_get(terps, value); ok {
		return terp.is_started
	}
	return false
}

terp_is_done :: proc(terps: ^Terps($T), value: ^T) -> bool {
	return !(value in terps.index)
}

terp_time_left :: proc(terps: ^Terps($T), value: ^T) -> f32 {
	if terp, ok := terp_get(terps, value); ok {
		return terp.duration * (1 - terp.progress)
	}
	return 0
}

terp_cancel :: proc(terps: ^Terps($T), value: ^T) -> bool {
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

terp_cancel_all :: proc(terps: ^Terps($T)) {
	clear(terps.terps)
	clear(terps.index)
}

terp_cleanup :: proc(terps: ^Terps($T)) {
	delete(terps.terps)
	delete(terps.index)
}
