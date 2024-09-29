@tool
extends SpotLight3D

func _process(delta: float) -> void:
	var time : float = float(Time.get_ticks_msec()) / 1000.;
	global_position.x += sin(time) * delta * 3;
