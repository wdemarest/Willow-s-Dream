extends Area3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass



func _on_body_entered(body: Node3D) -> void:
	if $Body/Hollowness/InnerFlame:
		$Body/Hollowness/InnerFlame.queue_free()
		
		$Light.omni_range /= 2;
		$Light.light_energy /= 3
		$Light.light_color = Color(0.98, 0.804, 0.735, 1.0) 
	
	
