class_name SnapPoint
extends Marker3D
## Ponto de encaixe de uma peça estrutural (GDD 011).
##
## A transformação global do marcador é exatamente onde a peça encaixada fica
## (posição e orientação). [member accepts] diz que tipo de peça cabe aqui.

@export var accepts: StringName = &"wall"
