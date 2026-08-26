package test

import "../terp"
import "base:intrinsics"
import "core:math"
import "core:math/ease"
import "core:math/linalg"
import "core:math/rand"
import "core:testing"

Vec2: typeid : linalg.Vector2f32

fps: int : 60
dt: f32 : 1 / f32(fps)

near :: proc(x, y: $T) -> bool where intrinsics.type_is_float(T) {
	return math.abs(x - y) < 0.001
}

count :: proc(t: ^terp.Terp($T), data: rawptr) {
	count_ptr := (^int)(data)
	count_ptr^ += 1
}

@(test)
test_terp_add :: proc(t: ^testing.T) {
	terps: terp.Terps(Vec2)
	defer terp.destroy(&terps)
	v1 := Vec2{1, 2}
	v2 := Vec2{5, 6}

	terp.to(&terps, &v1, Vec2{3, 4}, 10)

	testing.expect_value(t, len(terps.terps), 1)
	testing.expect_value(t, len(terps.index), 1)

	terp.to(&terps, &v2, Vec2{7, 8}, 11)

	testing.expect_value(t, len(terps.terps), 2)
	testing.expect_value(t, len(terps.index), 2)
}

@(test)
test_terp_get :: proc(t: ^testing.T) {
	terps: terp.Terps(Vec2)
	defer terp.destroy(&terps)
	v1 := Vec2{1, 2}
	v2 := Vec2{5, 6}
	v3 := Vec2{9, 10}

	terp.to(&terps, &v1, Vec2{3, 4}, 1)
	terp.to(&terps, &v2, Vec2{7, 8}, 2)

	t1, ok1 := terp.get(&terps, &v1)
	t2, ok2 := terp.get(&terps, &v2)
	t3, ok3 := terp.get(&terps, &v3)

	testing.expect(t, ok1)
	testing.expect(t, t1 != nil && t1.value == &v1)

	testing.expect(t, ok2)
	testing.expect(t, t2 != nil && t2.value == &v2)

	testing.expect(t, !ok3)
	testing.expect(t, t3 == nil)
}

@(test)
test_terp_update :: proc(t: ^testing.T) {
	terps: terp.Terps(Vec2)
	defer terp.destroy(&terps)
	v1 := Vec2{1, 2}
	v2 := Vec2{4, 8}

	terp.to(&terps, &v1, Vec2{2, 3}, 10)
	terp.to(&terps, &v2, Vec2{8, 16}, 20)

	// run halfway through terp 1, quarter through terp 2
	for _ in 0 ..< 5 * fps do terp.update(&terps, dt)

	testing.expect_value(t, len(&terps.terps), 2)
	testing.expect(t, near(v1.x, 1.5))
	testing.expect(t, near(v1.y, 2.5))
	testing.expect(t, near(v2.x, 5))
	testing.expect(t, near(v2.y, 10))

	// run all the way through terp 1, halfway through terp 2
	for _ in 0 ..< 5 * fps do terp.update(&terps, dt)

	testing.expect(t, near(v1.x, 2))
	testing.expect(t, near(v1.y, 3))
	testing.expect(t, near(v2.x, 6))
	testing.expect(t, near(v2.y, 12))

	// nudge one more frame so that terp 1 finishes
	terp.update(&terps, dt)

	testing.expect_value(t, len(&terps.terps), 1)

	// finish terp 2
	for _ in 0 ..< 11 * fps do terp.update(&terps, dt)

	testing.expect_value(t, len(&terps.terps), 0)
	testing.expect(t, near(v2.x, 8))
	testing.expect(t, near(v2.y, 16))
}

@(test)
test_terp_update_with_on_start :: proc(t: ^testing.T) {
	started: int = 0
	terps: terp.Terps(Vec2)
	defer terp.destroy(&terps)
	v1 := Vec2{1, 2}
	v2 := Vec2{4, 8}

	terp.to(&terps, &v1, Vec2{2, 3}, 10, on_start = count, data = &started)
	terp.to(&terps, &v2, Vec2{8, 16}, 20, on_start = count, data = &started)

	// start both terps
	for _ in 0 ..< 5 * fps do terp.update(&terps, dt)

	testing.expect_value(t, started, 2)

	// finish one terp
	for _ in 0 ..< 16 * fps do terp.update(&terps, dt)

	testing.expect_value(t, started, 2)
}

@(test)
test_terp_update_with_on_done :: proc(t: ^testing.T) {
	done: int = 0
	terps: terp.Terps(Vec2)
	defer terp.destroy(&terps)
	v1 := Vec2{1, 2}
	v2 := Vec2{4, 8}

	terp.to(&terps, &v1, Vec2{2, 3}, 10, on_done = count, data = &done)
	terp.to(&terps, &v2, Vec2{8, 16}, 20, on_done = count, data = &done)

	// start both terps; finish neither
	for _ in 0 ..< 5 * fps do terp.update(&terps, dt)

	testing.expect_value(t, done, 0)

	// finish one terp
	for _ in 0 ..< 6 * fps do terp.update(&terps, dt)

	testing.expect_value(t, done, 1)

	// finish both terps
	for _ in 0 ..< 10 * fps do terp.update(&terps, dt)

	testing.expect_value(t, done, 2)
}

@(test)
test_terp_update_with_delays :: proc(t: ^testing.T) {
	terps: terp.Terps(Vec2)
	defer terp.destroy(&terps)
	v1 := Vec2{1, 2}
	v2 := Vec2{4, 8}

	terp.to(&terps, &v1, Vec2{2, 3}, 10, 8)
	terp.to(&terps, &v2, Vec2{8, 16}, 20, 16)

	// expected timeline:
	//   8s: v1 starts
	//   16s: v2 starts
	//   18s: v1 ends
	//   36s: v2 ends

	// 7s: neither delay elapsed
	for _ in 0 ..< 7 * fps do terp.update(&terps, dt)

	t1, ok1 := terp.get(&terps, &v1)
	testing.expect(t, ok1)
	testing.expect(t, !t1.is_started)
	testing.expect(t, t1.progress == 0)
	t2, ok2 := terp.get(&terps, &v2)
	testing.expect(t, ok2)
	testing.expect(t, !t2.is_started)
	testing.expect(t, t2.progress == 0)

	// 9s: one delay elapsed
	for _ in 0 ..< 2 * fps do terp.update(&terps, dt)

	t1, ok1 = terp.get(&terps, &v1)
	testing.expect(t, ok1)
	testing.expect(t, t1.is_started)
	testing.expect(t, t1.progress > 0 && t1.progress < 1)
	t2, ok2 = terp.get(&terps, &v2)
	testing.expect(t, ok2)
	testing.expect(t, !t2.is_started)
	testing.expect(t, t2.progress == 0)

	// 17s: two delays elapsed
	for _ in 0 ..< 8 * fps do terp.update(&terps, dt)

	t1, ok1 = terp.get(&terps, &v1)
	testing.expect(t, ok1)
	testing.expect(t, t1.is_started)
	testing.expect(t, t1.progress > 0 && t1.progress < 1)
	t2, ok2 = terp.get(&terps, &v2)
	testing.expect(t, ok2)
	testing.expect(t, t2.is_started)
	testing.expect(t, t2.progress > 0 && t2.progress < 1)

	// 19s: two delays elapsed, one terp done
	for _ in 0 ..< 2 * fps do terp.update(&terps, dt)

	t1, ok1 = terp.get(&terps, &v1)
	testing.expect(t, !ok1)
	testing.expect(t, t1 == nil)
	t2, ok2 = terp.get(&terps, &v2)
	testing.expect(t, ok2)
	testing.expect(t, t2.is_started)
	testing.expect(t, t2.progress < 1)

	// 37s: two delays elapsed, two terps done
	for _ in 0 ..< 18 * fps do terp.update(&terps, dt)

	t1, ok1 = terp.get(&terps, &v1)
	testing.expect(t, !ok1)
	testing.expect(t, t1 == nil)
	t2, ok2 = terp.get(&terps, &v2)
	testing.expect(t, !ok2)
	testing.expect(t, t2 == nil)
}

@(test)
test_terp_update_repeat :: proc(t: ^testing.T) {
	terps: terp.Terps(f32)
	defer terp.destroy(&terps)
	v1: f32 = 1
	v2: f32 = 2

	terp.to(&terps, &v1, 2, 8, repeat = true)
	terp.to(&terps, &v2, 7, 10, repeat = true)

	// running for 12s should wrap around to 50% of terp 1 and 20% of terp 2
	for _ in 0 ..< 12 * fps do terp.update(&terps, dt)

	testing.expect_value(t, len(&terps.terps), 2)
	testing.expect(t, near(v1, 1.5))
	testing.expect(t, near(v2, 3))

	// running for another 14s (total 26s) should wrap around to 25% of terp 1 and 60% of terp 2
	for _ in 0 ..< 14 * fps do terp.update(&terps, dt)

	testing.expect_value(t, len(&terps.terps), 2)
	testing.expect(t, near(v1, 1.25))
	testing.expect(t, near(v2, 5))
}

@(test)
test_terp_update_with_on_repeat :: proc(t: ^testing.T) {
	count1: int = 0
	count2: int = 0

	terps: terp.Terps(f32)
	defer terp.destroy(&terps)
	v1: f32 = 1
	v2: f32 = 2

	terp.to(&terps, &v1, 3, 2, repeat = true, on_repeat = count, data = &count1)
	terp.to(&terps, &v2, 4, 3, repeat = true, on_repeat = count, data = &count2)

	// running for 11s should repeat the first terp 5 times, and the second terp 3 times
	for _ in 0 ..< 11 * fps do terp.update(&terps, dt)

	testing.expect_value(t, len(&terps.terps), 2)
	testing.expect_value(t, count1, 5)
	testing.expect_value(t, count2, 3)
}

@(test)
test_terp_update_round_trip :: proc(t: ^testing.T) {
	terps: terp.Terps(f32)
	defer terp.destroy(&terps)
	v1: f32 = 1
	v2: f32 = 2

	terp.to(&terps, &v1, 2, 10, round_trip = true)
	terp.to(&terps, &v2, 10, 16, round_trip = true)

	// running for 9s should reverse back to 20% of terp 1 and 87.5% of terp 2
	for _ in 0 ..< 9 * fps do terp.update(&terps, dt)

	testing.expect_value(t, len(&terps.terps), 2)
	testing.expect(t, near(v1, 1.2))
	testing.expect(t, near(v2, 9))

	// finish the first terp
	for _ in 0 ..< 2 * fps do terp.update(&terps, dt)

	testing.expect_value(t, len(&terps.terps), 1)

	terp1, ok1 := terp.get(&terps, &v1)
	terp2, ok2 := terp.get(&terps, &v2)

	testing.expect(t, !ok1)
	testing.expect(t, terp1 == nil)
	testing.expect(t, ok2)
	testing.expect(t, terp2.value == &v2)

	// finsh the second terp
	for _ in 0 ..< 6 * fps do terp.update(&terps, dt)

	testing.expect_value(t, len(&terps.terps), 0)

	terp2, ok2 = terp.get(&terps, &v2)

	testing.expect(t, !ok2)
	testing.expect(t, terp2 == nil)
}

@(test)
test_terp_update_round_trip_on_reverse :: proc(t: ^testing.T) {
	count1: int = 0
	count2: int = 0

	terps: terp.Terps(f32)
	defer terp.destroy(&terps)
	v1: f32 = 1
	v2: f32 = 2

	terp.to(&terps, &v1, 2, 10, round_trip = true, on_reverse = count, data = &count1)
	terp.to(&terps, &v2, 10, 16, round_trip = true, on_reverse = count, data = &count2)

	// running for 9s should reverse back to 20% of terp 1 and 87.5% of terp 2
	for _ in 0 ..< 9 * fps do terp.update(&terps, dt)

	testing.expect_value(t, len(&terps.terps), 2)
	testing.expect(t, near(v1, 1.2))
	testing.expect(t, near(v2, 9))

	// each terp should have reversed direction once
	testing.expect_value(t, count1, 1)
	testing.expect_value(t, count2, 1)

	// finish the terps
	for _ in 0 ..< 8 * fps do terp.update(&terps, dt)

	testing.expect_value(t, len(&terps.terps), 0)
	// each terp should still have reversed direction only once
	testing.expect_value(t, count1, 1)
	testing.expect_value(t, count2, 1)
}

@(test)
test_terp_update_round_trip_repeat :: proc(t: ^testing.T) {
	terps: terp.Terps(f32)
	defer terp.destroy(&terps)
	v1: f32 = 1
	v2: f32 = 2

	terp.to(&terps, &v1, 2, 8, repeat = true, round_trip = true)
	terp.to(&terps, &v2, 7, 10, repeat = true, round_trip = true)

	// running for 28s should reach 100% of terp 1 (3.5 trips) and 40% of terp 2 (2.8 trips)
	for _ in 0 ..< 28 * fps do terp.update(&terps, dt)

	testing.expect_value(t, len(&terps.terps), 2)
	testing.expect(t, near(v1, 2))
	testing.expect(t, near(v2, 4))
}

@(test)
test_terp_update_round_trip_on_repeat_on_reverse :: proc(t: ^testing.T) {
	count_repeats: int = 0
	count_reverses: int = 0

	terps: terp.Terps(f32)
	defer terp.destroy(&terps)
	v1: f32 = 1
	v2: f32 = 2

	terp.to(
		&terps,
		&v1,
		2,
		8,
		repeat = true,
		round_trip = true,
		on_repeat = count,
		data = &count_repeats,
	)
	terp.to(
		&terps,
		&v2,
		7,
		10,
		repeat = true,
		round_trip = true,
		on_reverse = count,
		data = &count_reverses,
	)

	// running for 28s should reach 100% of terp 1 over 3.5 trips, and 40% of terp 2 over 2.8 trips
	for _ in 0 ..< 28 * fps do terp.update(&terps, dt)

	testing.expect_value(t, len(&terps.terps), 2)
	testing.expect(t, near(v1, 2))
	testing.expect(t, near(v2, 4))

	testing.expect_value(t, count_repeats, 3) // 3 full trips
	testing.expect_value(t, count_reverses, 5) // 5 half-trips
}

@(test)
test_terp_update_many_random :: proc(t: ^testing.T) {
	terps: terp.Terps(f32)
	defer terp.destroy(&terps)
	num_targets :: 1000
	elapsed_time :: 3
	targets: [num_targets]f32
	starts: [num_targets]f32
	ends: [num_targets]f32
	durations: [num_targets]f32
	eases: [num_targets]ease.Ease
	expected_targets: map[int]f32
	defer delete(expected_targets)

	// create a large number of terps with random targets, durations, and easing functions
	for i in 0 ..< num_targets {
		targets[i] = f32(rand.int_range(1, 10))
		starts[i] = targets[i]
		ends[i] = f32(rand.int_range(20, 30))
		durations[i] = f32(rand.int_range(4, 8))
		eases[i] = rand.choice_enum(ease.Ease)
		terp.to(&terps, &targets[i], ends[i], durations[i], easing = eases[i])
		expected_targets[i] = linalg.lerp(starts[i], ends[i], ease.ease(eases[i], f32(1)))
	}

	// advance them all
	for _ in 0 ..< elapsed_time * fps do terp.update(&terps, dt)

	// make sure the intermediate terp results are consistent with what we can reconstruct from the input parameters
	for i in 0 ..< num_targets {
		terp_i, ok := terp.get(&terps, &targets[i])
		testing.expect(t, ok)
		expected_progress: f32
		// sum up the progress in the same way as the update loop to compensate for floating point imprecision
		for _ in 0 ..< elapsed_time * fps do expected_progress += dt / durations[i]
		testing.expect(t, near(terp_i.progress, expected_progress))
		eased := ease.ease(eases[i], expected_progress)
		expected_value := linalg.lerp(starts[i], ends[i], eased)
		target_i := targets[i]
		testing.expect(t, near(target_i, expected_value))
	}

	// finish all the terps and make sure the final terp'ed results match the precalculated expectations
	for _ in 0 ..< 8 * fps + 1 do terp.update(&terps, dt)

	testing.expect(t, len(terps.terps) == 0)
	for i in 0 ..< num_targets do testing.expect(t, near(targets[i], expected_targets[i]))
}

@(test)
test_time_left :: proc(t: ^testing.T) {
	terps: terp.Terps(f32)
	defer terp.destroy(&terps)
	v1 : f32 = 10
	v2 : f32 = 20
	v3 : f32 = 30
	v4 : f32 = 40

	terp.to(&terps, &v1, 20, 10)
	terp.to(&terps, &v2, 40, 10, round_trip = true)
	terp.to(&terps, &v3, 60, 10, repeat = true)
	terp.to(&terps, &v4, 80, 10, round_trip = true, repeat = true)

	for _ in 0 ..< 6 * fps do terp.update(&terps, dt)

	testing.expect(t, near(terp.time_left(&terps, &v1), 4))
	testing.expect(t, near(terp.time_left(&terps, &v2), 4))

	for _ in 0 ..< 8 * fps do terp.update(&terps, dt)

	testing.expect(t, near(terp.time_left(&terps, &v3), 6))
	testing.expect(t, near(terp.time_left(&terps, &v4), 6))
}

@(test)
test_terp_cancel_before_starting :: proc(t: ^testing.T) {
	terps: terp.Terps(Vec2)
	defer terp.destroy(&terps)
	v1 := Vec2{1, 2}
	v2 := Vec2{5, 6}

	terp.to(&terps, &v1, Vec2{3, 4}, 1)
	terp.to(&terps, &v2, Vec2{7, 8}, 2)

	// cancel one terp
	canceled := terp.cancel(&terps, &v1)
	t1, ok1 := terp.get(&terps, &v1)
	t2, ok2 := terp.get(&terps, &v2)

	testing.expect(t, canceled)
	testing.expect(t, !ok1)
	testing.expect(t, t1 == nil)
	testing.expect(t, ok2)
	testing.expect(t, t2 != nil && t2.value == &v2)
	testing.expect_value(t, len(&terps.terps), 1)
	testing.expect_value(t, len(&terps.index), 1)

	// cancel last terp
	canceled = terp.cancel(&terps, &v2)
	t2, ok2 = terp.get(&terps, &v2)

	testing.expect(t, canceled)
	testing.expect(t, !ok2)
	testing.expect(t, t2 == nil)
	testing.expect_value(t, len(&terps.terps), 0)
	testing.expect_value(t, len(&terps.index), 0)

	// cancel nonexistent terp
	canceled = terp.cancel(&terps, &v1)

	testing.expect(t, !canceled)
}

@(test)
test_terp_cancel_after_starting :: proc(t: ^testing.T) {
	terps: terp.Terps(Vec2)
	defer terp.destroy(&terps)
	v1 := Vec2{1, 2}
	v2 := Vec2{4, 8}

	terp.to(&terps, &v1, Vec2{2, 3}, 10)
	terp.to(&terps, &v2, Vec2{8, 16}, 20)

	// start both terps, finish neither
	for _ in 0 ..< 5 * fps do terp.update(&terps, dt)
	// cancel one terp
	canceled := terp.cancel(&terps, &v1)
	t1, ok1 := terp.get(&terps, &v1)
	t2, ok2 := terp.get(&terps, &v2)

	testing.expect(t, canceled)
	testing.expect(t, !ok1)
	testing.expect(t, t1 == nil)
	testing.expect(t, ok2)
	testing.expect(t, t2 != nil && t2.value == &v2)
	testing.expect_value(t, len(&terps.terps), 1)
	testing.expect_value(t, len(&terps.index), 1)

	// run the remaining terp, don't finish
	for _ in 0 ..< 5 * fps do terp.update(&terps, dt)
	// cancel last terp
	canceled = terp.cancel(&terps, &v2)
	t2, ok2 = terp.get(&terps, &v2)

	testing.expect(t, canceled)
	testing.expect(t, !ok2)
	testing.expect(t, t2 == nil)
	testing.expect_value(t, len(&terps.terps), 0)
	testing.expect_value(t, len(&terps.index), 0)

	// cancel nonexistent terp
	canceled = terp.cancel(&terps, &v1)

	testing.expect(t, !canceled)
}
