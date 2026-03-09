extends Node

# Banco de dados do MVP (Pode ser facilmente adaptado para um arquivo JSON no futuro)
var levels = [
	{
		"word": "BOLA",
		"syllables": ["BO", "LA"],
		"wrong_syllables": ["MA", "CE"], # Distratores para desafiar a criança
		"image_name": "bola"
	},
	{
		"word": "GATO",
		"syllables": ["GA", "TO"],
		"wrong_syllables": ["RA", "PO"],
		"image_name": "gato"
	},
	{
		"word": "CASA",
		"syllables": ["CA", "SA"],
		"wrong_syllables": ["LA", "DO"],
		"image_name": "casa"
	}
]

# Função utilitária para buscar os dados de uma fase
func get_level_data(level_index: int) -> Dictionary:
	if level_index >= 0 and level_index < levels.size():
		return levels[level_index]
	return {}

# Retorna quantas fases temos no total
func get_total_levels() -> int:
	return levels.size()
