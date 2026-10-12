extends TestCase

## Synthesized sound effects: each is generated, non-silent, and plays.

func _peak(wav: AudioStreamWAV) -> int:
	var peak := 0
	for i in range(0, wav.data.size(), 2):
		peak = max(peak, absi(wav.data.decode_s16(i)))
	return peak

func test_every_sound_is_generated_and_audible() -> void:
	for sound in Sfx.SOUNDS:
		var wav := Sfx.stream(sound)
		assert_true(wav.data.size() > Sfx.SAMPLE_RATE / 50, "%s has samples" % sound)
		assert_true(_peak(wav) > 3000, "%s is audible (peak %d)" % [sound, _peak(wav)])

func test_sounds_are_the_same_every_time() -> void:
	# Seeded noise: a swing sounds like a swing, not a different hiss each run.
	var first := Sfx._make("swing").data
	assert_eq(Sfx._make("swing").data, first, "swing is deterministic")

func test_play_uses_the_pool() -> void:
	Sfx.play("swing")
	Sfx.play("shot", -10.0)
	var pool := tree.root.get_node_or_null("SfxPool")
	assert_true(pool != null, "pool is on the scene root")
	assert_eq(pool.get_child_count(), Sfx.POOL_SIZE, "pool size")
	await tree.process_frame
	assert_true(pool.get_children().any(func(p): return p.stream == Sfx.stream("swing")), "a player got the swing sound")

func test_the_ring_spinning_down_is_longer_than_half_a_second() -> void:
	assert_true(Sfx.SOUNDS.has("ring_down"), "listed")
	assert_true(Sfx.stream("ring_down").data.size() > Sfx.SAMPLE_RATE / 2 * 2, "longer than half a second of 16-bit samples")
