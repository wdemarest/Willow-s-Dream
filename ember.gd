extends RigidBody3D

@export var totalLifetime : float = 5

var mainLightInitialEnergy : float
var fogGlowInitialEnergy : float

var mainLight
var fogGlow

func _ready() -> void:
	mainLight = $"MainLight"
	fogGlow = $"FogGlow"
	
	mainLightInitialEnergy = mainLight.light_energy
	fogGlowInitialEnergy = fogGlow.light_energy


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	mainLight.light_energy -= (mainLightInitialEnergy / totalLifetime) * delta;
	fogGlow.light_energy -= (fogGlowInitialEnergy / totalLifetime) * 0.5 * delta;
	
	if mainLight.light_energy <= 0:
		queue_free()
		
