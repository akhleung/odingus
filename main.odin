package odingus

import "core:container/handle_map"
import "core:fmt"
import "core:math/ease"
import "core:math/linalg"
import "core:math/rand"
import "core:os"
import "core:strconv"
import "core:time"
import "terp"

Handle :: handle_map.Handle64

Ease :: struct($T: typeid) {
	target:     ^T,
	start:      T,
	end:        T,
	t:          f32,
	duration:   f32,
	delay:      f32,
	easing:     ease.Ease,
	generation: u32,
	on_done:    proc(ease: ^Ease(T), user_data: rawptr),
	user_data:  rawptr,
	pool:       ^Ease_Pool(T),
}

Ease_Pool :: struct($T: typeid) {
	eases:       [dynamic]Ease(T),

	//// methods ////
	update:      proc(this: ^Ease_Pool(T), dt: f32),
	add:         proc(
		this: ^Ease_Pool(T),
		target: ^T,
		to: T,
		duration: f32,
		delay: f32,
		easing: ease.Ease,
		on_done: proc(ease: ^Ease(T), user_data: rawptr) = nil,
		user_data: rawptr = nil,
	) -> Handle,
	is_complete: proc(this: ^Ease_Pool(T), handle: Handle) -> bool,
}

noop :: proc(ease: ^Ease($T), user_data: rawptr) {}

num_done := 0
count_done :: proc(ease: $T, user_data: rawptr) {
	num_done += 1
}

count_flux :: proc(flux: ^ease.Flux_Map($T), data: rawptr) {
	num_done += 1
}

ding :: proc(ease: ^Ease($T), user_data: rawptr) {
	fmt.println("Done! Final value is", ease.target^)
}

ease_pool_init :: proc(pool: ^Ease_Pool($T), size: int = 0) {
	pool.update = ease_pool_update
	pool.add = ease_pool_add
	pool.is_complete = ease_pool_is_complete
	if size > 0 {
		reserve(&pool.eases, size)
	}
}

ease_pool_add :: proc(
	this: ^Ease_Pool($T),
	target: ^T,
	to: T,
	duration: f32,
	delay: f32 = 0,
	easing: ease.Ease = .Linear,
	on_done: proc(ease: ^Ease(T), user_data: rawptr) = nil,
	user_data: rawptr = nil,
) -> Handle {
	to := to
	e, index := get_ease(&this.eases)
	e.start = target^
	e.target = target
	e.end = to
	e.t = 0
	e.duration = duration
	e.delay = delay
	e.easing = easing
	e.on_done = on_done
	e.user_data = user_data
	e.pool = this
	e.generation += 1
	return {idx = index, gen = e.generation}
}

ease_pool_update :: proc(this: ^Ease_Pool($T), dt: f32) {
	for &e in this.eases {
		if e.t >= 1 do continue
		dt := dt
		if e.delay > 0 {
			e.delay -= dt
			if (e.delay < 0) {
				dt = -e.delay
				e.delay = 0
			} else {
				continue
			}
		}

		e.t += dt / e.duration
		eased := ease.ease(e.easing, e.t)

		e.target^ = linalg.lerp(e.start, e.end, eased)
		if e.t >= 1 && e.on_done != nil {
			e.on_done(&e, e.user_data)
		}
	}
}

ease_pool_is_complete :: proc(this: ^Ease_Pool($T), handle: Handle) -> bool {
	if int(handle.idx) >= len(this.eases) do return true
	e := this.eases[handle.idx]
	if e.generation != handle.gen do return true
	return e.t >= 1
}

@(private = "file")
get_ease :: proc(eases: ^[dynamic]Ease($T)) -> (^Ease(T), u32) {
	if index, ok := get_unused_index(eases); ok {
		return &eases[index], index
	}
	index := u32(len(eases))
	append(eases, Ease(T){})
	return &eases[index], index
}

@(private = "file")
get_unused_index :: proc(eases: ^[dynamic]Ease($T)) -> (index: u32, ok: bool) {
	for e, i in eases {
		if e.t >= 1 {
			return u32(i), true
		}
	}
	return
}

main :: proc() {

	Vec2 :: linalg.Vector2f32

	num_tweens: int = 500
	min_dur: int = 1
	max_dur: int = 1
	args := os.args
	if len(args) >= 2 {
		if n, ok := strconv.parse_int(args[1]); ok {
			num_tweens = n
		}
	}
	if len(args) >= 3 {
		if n, ok := strconv.parse_int(args[2]); ok {
			min_dur = n
		}
	}
	if min_dur < 1 {
		min_dur = 1
	}
	if len(args) >= 4 {
		if n, ok := strconv.parse_int(args[3]); ok {
			max_dur = n
		}
	}
	if max_dur < 1 {
		max_dur = 1
	}
	if max_dur < min_dur {
		max_dur = min_dur
	}

	fps: f32 = 60
	dt: f32 = 1 / fps
	vecs: []Vec2 = make([]Vec2, num_tweens)
	ep: Ease_Pool(Vec2)

	ease_pool_init(&ep, num_tweens)
	fmt.println(
		"Generating",
		num_tweens,
		"vector eases with durations in",
		[]int{min_dur, max_dur},
	)
	for i := 0; i < num_tweens; i += 1 {
		vecs[i].x = rand.float32_range(0, 25)
		vecs[i].y = rand.float32_range(0, 25)
		tx := rand.float32_range(25, 50)
		ty := rand.float32_range(25, 50)
		to: Vec2 = {tx, ty}
		ep.add(
			&ep,
			&vecs[i],
			to,
			f32(rand.int_range(min_dur, max_dur + 1)),
			f32(rand.int_range(min_dur, max_dur + 1)),
			.Quintic_Out,
			count_done,
		)
	}

	start := time.now()
	total: f32
	for num_done < num_tweens {
		ep.update(&ep, dt)
		total += dt
	}
	dur := time.since(start)
	timing := time.duration_milliseconds(dur)
	fmt.println(num_done, "vector eases over", total, "seconds took", timing, "ms")

	terps: terp.Terps(Vec2)
	terp.terp_reserve(&terps, num_tweens)

	fmt.println(
		"Generating",
		num_tweens,
		"vector terps with durations in",
		[]int{min_dur, max_dur},
	)
	for i := 0; i < num_tweens; i += 1 {
		vecs[i].x = rand.float32_range(0, 25)
		vecs[i].y = rand.float32_range(0, 25)
		tx := rand.float32_range(25, 50)
		ty := rand.float32_range(25, 50)
		to: Vec2 = {tx, ty}
		terp.terp_to(
			&terps,
			&vecs[i],
			to,
			f32(rand.int_range(min_dur, max_dur + 1)),
			f32(rand.int_range(min_dur, max_dur + 1)),
			.Quadratic_Out,
			.Forward_Once,
			count_done,
		)
	}

	total = 0
	num_done = 0
	start = time.now()
	for num_done < num_tweens {
		terp.terp_update(&terps, dt)
		total += dt
	}
	dur = time.since(start)
	timing = time.duration_milliseconds(dur)
	fmt.println(num_done, "vector terps over", total, "seconds took", timing, "ms")
}
