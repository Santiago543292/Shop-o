extends Node

const DB := {
	"ambience": -18.0,
	"footstep": -11.0,
	"hum_near": -15.0,
	"hum_far": -55.0,
	"beep": -4.0,
	"search": 2.0,
	"bus": -1.0,
}

## One-shots share a single player so two of them can never overlap into
## distortion; the looping beds have their own players.
const SOUNDS := {
	"ambience": "res://Assets/Sounds/bijan6207-night-horror-sound-effect-167307.mp3",
	"bus": "res://Assets/Sounds/freesound_community-bus-idle-to-drive-off-65780.mp3",
	"search": "res://Assets/Sounds/Searching sound effect.mp3",
	"beep": "res://Assets/Sounds/jokerzillagames-beep-412601.mp3",
	"hum": "res://Assets/Sounds/soul_serenity_sounds-computer-humming-236384.mp3",
}

const FOOTSTEPS := [
	"res://Assets/Sounds/yarzur_ofc-st1-footstep-sfx-323053.mp3",
	"res://Assets/Sounds/yarzur_ofc-st2-footstep-sfx-323055.mp3",
	"res://Assets/Sounds/yarzur_ofc-st3-footstep-sfx-323056.mp3",
]

var _ambience: AudioStreamPlayer
var _hum: AudioStreamPlayer
var _oneshot: AudioStreamPlayer

## Which sound the shared one-shot player last played — lets a test confirm a
## short UI sound actually fired, even after it has finished.
var last_oneshot := ""

# Footstep order: a shuffled queue, refilled when it runs out. The first of a
# new queue is never the sound that just played, so the same footstep can
# never come twice in a row.
var _footstep_queue: Array[int] = []
var _last_footstep := -1
var _ambience_started := false


func _ready() -> void:
	_ambience = _make_player()
	_hum = _make_player()
	_oneshot = _make_player()

	# The hum is a bed that runs the whole time; its volume is driven by
	# proximity, not by starting and stopping it.
	var hum_stream := _load("hum")
	if hum_stream is AudioStream:
		_set_loop(hum_stream, true)
		_hum.stream = hum_stream
		_hum.volume_db = DB["hum_far"]
		_hum.play()


func _make_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Master"
	add_child(p)
	return p


## Loop is spelled differently per stream type.
func _set_loop(stream: AudioStream, on: bool) -> void:
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = (
			AudioStreamWAV.LOOP_FORWARD if on else AudioStreamWAV.LOOP_DISABLED)
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = on
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = on


func _load(key: String) -> AudioStream:
	if not SOUNDS.has(key):
		return null
	return load(SOUNDS[key]) as AudioStream


# --- ambience ---------------------------------------------------------------

func start_ambience() -> void:
	if _ambience_started:
		return
	_ambience_started = true
	var s := _load("ambience")
	if s is AudioStream:
		_set_loop(s, true)
		_ambience.stream = s
		_ambience.volume_db = DB["ambience"]
		_ambience.play()


func stop_ambience() -> void:
	_ambience.stop()


# --- footsteps --------------------------------------------------------------

## Play the next footstep. Never repeats the previous one.
func play_footstep() -> void:
	if _footstep_queue.is_empty():
		_refill_footsteps()
	if _footstep_queue.is_empty():
		return
	var idx: int = _footstep_queue.pop_front()
	_last_footstep = idx
	_play_one(idx, DB["footstep"])


func _refill_footsteps() -> void:
	_footstep_queue = [0, 1, 2]
	_footstep_queue.shuffle()
	# If the reshuffled queue starts with what we just played, swap it so the
	# same sound can never land twice in a row.
	if _footstep_queue[0] == _last_footstep and _footstep_queue.size() > 1:
		_footstep_queue[0] = _footstep_queue[1]
		_footstep_queue[1] = _last_footstep


func _play_one(idx: int, db: float) -> void:
	if idx < 0 or idx >= FOOTSTEPS.size():
		return
	var s := load(FOOTSTEPS[idx]) as AudioStream
	if s == null:
		return
	_oneshot.stream = s
	_oneshot.volume_db = db
	_oneshot.play()


# --- light hum --------------------------------------------------------------

## 0.0 = far from every light, 1.0 = right underneath one.
func set_hum_proximity(t: float) -> void:
	var c := clampf(t, 0.0, 1.0)
	# Linear falloff: a natural fade that starts becoming noticeable a good
	# way out, rather than a wall of sound that only appears at the last moment.
	_hum.volume_db = lerpf(DB["hum_far"], DB["hum_near"], c)


# --- one-shots --------------------------------------------------------------

func play_beep() -> void:
	_play_key("beep", DB["beep"])


func play_search() -> void:
	_play_key("search", DB["search"])


func play_bus_arrive() -> void:
	_play_key("bus", DB["bus"])
	# Ramp up so the bus reads as approaching rather than already alongside.
	var tw := create_tween()
	tw.tween_method(_set_oneshot_db, -24.0, DB["bus"], 2.0)


func _set_oneshot_db(db: float) -> void:
	if _oneshot != null:
		_oneshot.volume_db = db


## Play any sound in the DB table by key (used by cutscenes / future SFX).
func play_sound(key: String) -> void:
	if not DB.has(key):
		return
	_play_key(key, DB[key])


func _play_key(key: String, db: float) -> void:
	var s := _load(key)
	if s == null:
		return
	_oneshot.stream = s
	_oneshot.volume_db = db
	last_oneshot = key
	_oneshot.play()
