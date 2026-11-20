class_name BuildingCatalog
extends Resource
## Lista ordenada das peças disponíveis no menu de construção (ordem = teclas 1 a N).

@export var pieces: Array[BuildingPieceDefinition] = []


func get_piece(id: StringName) -> BuildingPieceDefinition:
	for piece in pieces:
		if piece != null and piece.id == id:
			return piece
	return null
