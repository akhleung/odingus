package test

import "../terp"
import "base:intrinsics"
import "core:math"
import "core:math/ease"
import "core:math/linalg"
import "core:math/rand"
import "core:testing"

Vec2 : typeid : linalg.Vector2f32

fps : int : 60
dt : f32 : 1 / f32(fps)

near :: proc(x, y: $T) -> bool where intrinsics.type_is_float(T) {
	return math.abs(x - y) < 0.001
}

// WARNING: be careful if reusing these globals and callbacks in multiple tests, in the presence of multithreading

started := 0
on_start :: proc(_terp: ^terp.Terp($T), _user_data: rawptr) {
	started += 1
}

done := 0
on_done :: proc(_terp: ^terp.Terp($T), _user_data: rawptr) {
	done += 1
}

@(test)
test_terp_add :: proc(t: ^testing.T) {
	terps: terp.Terps(Vec2)
	defer terp.terp_cleanup(&terps)
	v1 := Vec2{1, 2}
	v2 := Vec2{5, 6}

	terp.terp_to(&terps, &v1, Vec2{3, 4}, 10)

	testing.expect_value(t, len(terps.terps), 1)
	testing.expect_value(t, len(terps.index), 1)

	terp.terp_to(&terps, &v2, Vec2{7, 8}, 11)

	testing.expect_value(t, len(terps.terps), 2)
	testing.expect_value(t, len(terps.index), 2)
}

@(test)
test_terp_get :: proc(t: ^testing.T) {
	terps: terp.Terps(Vec2)
	defer terp.terp_cleanup(&terps)
	v1 := Vec2{1, 2}
	v2 := Vec2{5, 6}
	v3 := Vec2{9, 10}

	terp.terp_to(&terps, &v1, Vec2{3, 4}, 1)
	terp.terp_to(&terps, &v2, Vec2{7, 8}, 2)

	t1, ok1 := terp.terp_get(&terps, &v1)
	t2, ok2 := terp.terp_get(&terps, &v2)
	t3, ok3 := terp.terp_get(&terps, &v3)

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
	defer terp.terp_cleanup(&terps)
	v1 := Vec2{1, 2}
	v2 := Vec2{4, 8}

	terp.terp_to(&terps, &v1, Vec2{2, 3}, 10)
	terp.terp_to(&terps, &v2, Vec2{8, 16}, 20)

	// run halfway through terp 1, quarter through terp 2
	for _ in 0 ..< 5 * fps do terp.terp_update(&terps, dt)

	testing.expect_value(t, len(&terps.terps), 2)
	testing.expect(t, near(v1.x, 1.5))
	testing.expect(t, near(v1.y, 2.5))
	testing.expect(t, near(v2.x, 5))
	testing.expect(t, near(v2.y, 10))

	// run all the way through terp 1, halfway through terp 2
	for _ in 0 ..< 5 * fps do terp.terp_update(&terps, dt)

	testing.expect(t, near(v1.x, 2))
	testing.expect(t, near(v1.y, 3))
	testing.expect(t, near(v2.x, 6))
	testing.expect(t, near(v2.y, 12))

	// nudge one more frame so that terp 1 finishes
	terp.terp_update(&terps, dt)

	testing.expect_value(t, len(&terps.terps), 1)

	// finish terp 2
	for _ in 0 ..< 11 * fps do terp.terp_update(&terps, dt)

	testing.expect_value(t, len(&terps.terps), 0)
	testing.expect(t, near(v2.x, 8))
	testing.expect(t, near(v2.y, 16))
}

@(test)
test_terp_update_with_on_start :: proc(t: ^testing.T) {
	started = 0
	terps: terp.Terps(Vec2)
	defer terp.terp_cleanup(&terps)
	v1 := Vec2{1, 2}
	v2 := Vec2{4, 8}

	terp.terp_to(&terps, &v1, Vec2{2, 3}, 10, on_start = on_start)
	terp.terp_to(&terps, &v2, Vec2{8, 16}, 20, on_start = on_start)

	// start both terps
	for _ in 0 ..< 5 * fps do terp.terp_update(&terps, dt)

	testing.expect_value(t, started, 2)

	// finish one terp
	for _ in 0 ..< 16 * fps do terp.terp_update(&terps, dt)

	testing.expect_value(t, started, 2)
}

@(test)
test_terp_update_with_on_done :: proc(t: ^testing.T) {
	done = 0
	terps: terp.Terps(Vec2)
	defer terp.terp_cleanup(&terps)
	v1 := Vec2{1, 2}
	v2 := Vec2{4, 8}

	terp.terp_to(&terps, &v1, Vec2{2, 3}, 10, on_done = on_done)
	terp.terp_to(&terps, &v2, Vec2{8, 16}, 20, on_done = on_done)

	// start both terps; finish neither
	for _ in 0 ..< 5 * fps do terp.terp_update(&terps, dt)

	testing.expect_value(t, done, 0)

	// finish one terp
	for _ in 0 ..< 6 * fps do terp.terp_update(&terps, dt)

	testing.expect_value(t, done, 1)

	// finish both terps
	for _ in 0 ..< 10 * fps do terp.terp_update(&terps, dt)

	testing.expect_value(t, done, 2)
}

@(test)
test_terp_update_with_delays :: proc(t: ^testing.T) {
	terps: terp.Terps(Vec2)
	defer terp.terp_cleanup(&terps)
	v1 := Vec2{1, 2}
	v2 := Vec2{4, 8}

	terp.terp_to(&terps, &v1, Vec2{2, 3}, 10, 8)
	terp.terp_to(&terps, &v2, Vec2{8, 16}, 20, 16)

	// expected timeline:
	//   8s: v1 starts
	//   16s: v2 starts
	//   18s: v1 ends
	//   36s: v2 ends

	// 7s: neither delay elapsed
	for _ in 0 ..< 7 * fps do terp.terp_update(&terps, dt)

	t1, ok1 := terp.terp_get(&terps, &v1)
	testing.expect(t, ok1)
	testing.expect(t, !t1.is_started)
	testing.expect(t, t1.progress == 0)
	t2, ok2 := terp.terp_get(&terps, &v2)
	testing.expect(t, ok2)
	testing.expect(t, !t2.is_started)
	testing.expect(t, t2.progress == 0)

	// 9s: one delay elapsed
	for _ in 0 ..< 2 * fps do terp.terp_update(&terps, dt)

	t1, ok1 = terp.terp_get(&terps, &v1)
	testing.expect(t, ok1)
	testing.expect(t, t1.is_started)
	testing.expect(t, t1.progress > 0 && t1.progress < 1)
	t2, ok2 = terp.terp_get(&terps, &v2)
	testing.expect(t, ok2)
	testing.expect(t, !t2.is_started)
	testing.expect(t, t2.progress == 0)

	// 17s: two delays elapsed
	for _ in 0 ..< 8 * fps do terp.terp_update(&terps, dt)

	t1, ok1 = terp.terp_get(&terps, &v1)
	testing.expect(t, ok1)
	testing.expect(t, t1.is_started)
	testing.expect(t, t1.progress > 0 && t1.progress < 1)
	t2, ok2 = terp.terp_get(&terps, &v2)
	testing.expect(t, ok2)
	testing.expect(t, t2.is_started)
	testing.expect(t, t2.progress > 0 && t2.progress < 1)

	// 19s: two delays elapsed, one terp done
	for _ in 0 ..< 2 * fps do terp.terp_update(&terps, dt)

	t1, ok1 = terp.terp_get(&terps, &v1)
	testing.expect(t, !ok1)
	testing.expect(t, t1 == nil)
	t2, ok2 = terp.terp_get(&terps, &v2)
	testing.expect(t, ok2)
	testing.expect(t, t2.is_started)
	testing.expect(t, t2.progress < 1)

	// 37s: two delays elapsed, two terps done
	for _ in 0 ..< 18 * fps do terp.terp_update(&terps, dt)

	t1, ok1 = terp.terp_get(&terps, &v1)
	testing.expect(t, !ok1)
	testing.expect(t, t1 == nil)
	t2, ok2 = terp.terp_get(&terps, &v2)
	testing.expect(t, !ok2)
	testing.expect(t, t2 == nil)
}

@(test)
test_terp_update_many_random :: proc(t: ^testing.T) {
	terps: terp.Terps(f32)
	defer terp.terp_cleanup(&terps)
	num_targets :: 1000
	elapsed_time :: 3
	targets: [num_targets]f32
	starts: [num_targets]f32
	ends: [num_targets]f32
	durations : [num_targets]f32
	eases: [num_targets]ease.Ease
	expected_targets : map[^f32]f32
	defer delete(expected_targets)

	// create a large number of terps with random targets, durations, and easing functions
	for i in 0 ..< num_targets {
		targets[i] = f32(rand.int_range(1, 10))
		starts[i] = targets[i]
		ends[i] = f32(rand.int_range(20, 30))
		durations[i] =f32(rand.int_range(4, 8))
		eases[i] = rand.choice_enum(ease.Ease)
		terp.terp_to(
			&terps,
			&targets[i],
			ends[i],
			durations[i],
			easing = eases[i],
		)
		expected_targets[&targets[i]] = linalg.lerp(starts[i], ends[i], ease.ease(eases[i], f32(1)))
	}

	// advance them all
	for _ in 0 ..< elapsed_time * fps do terp.terp_update(&terps, dt)

	// make sure the intermediate terp results are consistent with what we can reconstruct from the input parameters
	for i in 0 ..< num_targets {
		terp_i, ok := terp.terp_get(&terps, &targets[i])
		testing.expect(t, ok)
		expected_progress : f32
		// sum up the progress in the same way as the update loop to compensate for floating point imprecision
		for _ in 0 ..< elapsed_time * fps do expected_progress += dt / durations[i]
		testing.expect(t, near(terp_i.progress, expected_progress))
		eased := ease.ease(eases[i], expected_progress)
		expected_value := linalg.lerp(starts[i], ends[i], eased)
		target_i := targets[i]
		testing.expect(t, near(target_i, expected_value))
	}

	// finish all the terps and make sure the final terp'ed results match the precalculated expectations
	for _ in 0 ..< 8 * fps + 1 do terp.terp_update(&terps, dt)

	testing.expect(t, len(terps.terps) == 0)
	for i in 0 ..< num_targets do testing.expect(t, near(targets[i], expected_targets[&targets[i]]))
}

@(test)
test_terp_cancel_before_starting :: proc(t: ^testing.T) {
	terps: terp.Terps(Vec2)
	defer terp.terp_cleanup(&terps)
	v1 := Vec2{1, 2}
	v2 := Vec2{5, 6}

	terp.terp_to(&terps, &v1, Vec2{3, 4}, 1)
	terp.terp_to(&terps, &v2, Vec2{7, 8}, 2)

	// cancel one terp
	canceled := terp.terp_cancel(&terps, &v1)
	t1, ok1 := terp.terp_get(&terps, &v1)
	t2, ok2 := terp.terp_get(&terps, &v2)

	testing.expect(t, canceled)
	testing.expect(t, !ok1)
	testing.expect(t, t1 == nil)
	testing.expect(t, ok2)
	testing.expect(t, t2 != nil && t2.value == &v2)
	testing.expect_value(t, len(&terps.terps), 1)
	testing.expect_value(t, len(&terps.index), 1)

	// cancel last terp
	canceled = terp.terp_cancel(&terps, &v2)
	t2, ok2 = terp.terp_get(&terps, &v2)

	testing.expect(t, canceled)
	testing.expect(t, !ok2)
	testing.expect(t, t2 == nil)
	testing.expect_value(t, len(&terps.terps), 0)
	testing.expect_value(t, len(&terps.index), 0)

	// cancel nonexistent terp
	canceled = terp.terp_cancel(&terps, &v1)

	testing.expect(t, !canceled)
}

@(test)
test_terp_cancel_after_starting :: proc(t: ^testing.T) {
	terps: terp.Terps(Vec2)
	defer terp.terp_cleanup(&terps)
	v1 := Vec2{1, 2}
	v2 := Vec2{4, 8}

	terp.terp_to(&terps, &v1, Vec2{2, 3}, 10)
	terp.terp_to(&terps, &v2, Vec2{8, 16}, 20)

	// start both terps, finish neither
	for _ in 0 ..< 5 * fps do terp.terp_update(&terps, dt)
	// cancel one terp
	canceled := terp.terp_cancel(&terps, &v1)
	t1, ok1 := terp.terp_get(&terps, &v1)
	t2, ok2 := terp.terp_get(&terps, &v2)

	testing.expect(t, canceled)
	testing.expect(t, !ok1)
	testing.expect(t, t1 == nil)
	testing.expect(t, ok2)
	testing.expect(t, t2 != nil && t2.value == &v2)
	testing.expect_value(t, len(&terps.terps), 1)
	testing.expect_value(t, len(&terps.index), 1)

	// run the remaining terp, don't finish
	for _ in 0 ..< 5 * fps do terp.terp_update(&terps, dt)
	// cancel last terp
	canceled = terp.terp_cancel(&terps, &v2)
	t2, ok2 = terp.terp_get(&terps, &v2)

	testing.expect(t, canceled)
	testing.expect(t, !ok2)
	testing.expect(t, t2 == nil)
	testing.expect_value(t, len(&terps.terps), 0)
	testing.expect_value(t, len(&terps.index), 0)

	// cancel nonexistent terp
	canceled = terp.terp_cancel(&terps, &v1)

	testing.expect(t, !canceled)
}
