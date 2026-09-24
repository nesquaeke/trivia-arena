class_name TrapDoor
extends AnimatableBody3D
## Menteşeli sahne kapağı. Gövdenin kendisi menteşe etrafında döner; ebeveyn
## düğümü döndürmek fizik gövdesini taşımıyordu (görsel açılıyor, zemin
## yerinde kalıyordu). `angle` değiştikçe gövde fizik karesinde yer değiştirir.

var hinge := Transform3D.IDENTITY    # dünya uzayında menteşe çerçevesi
var offset := Vector3.ZERO           # gövde merkezinin menteşeye göre yeri
var angle := 0.0:
	set(v):
		angle = v
		_apply()

func _ready() -> void:
	sync_to_physics = true
	_apply()

func _apply() -> void:
	if not is_inside_tree():
		return
	global_transform = hinge * Transform3D(Basis(Vector3.BACK, angle), Vector3.ZERO) * Transform3D(Basis.IDENTITY, offset)
