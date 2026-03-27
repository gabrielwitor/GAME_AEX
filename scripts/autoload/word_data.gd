extends Node

var JsonRequest = HTTPRequest.new()
var ImagemRequest = HTTPRequest.new()
var AudioRequest = HTTPRequest.new()
var AudioSilabaRequest = HTTPRequest.new()

var array_dicionario: Array
var array_dicionario_imagens: Array
var texturas: Array
var audio_palavra
var audios_silabas: Array
var cont_silaba: int = 0

var index = 0
var cont_img = 0

var array_palavras: Array
var array_imagens: Array

var dicionario: Dictionary = {
	"palavra": "",
	"silabas": [],
	"imagens": null,
	"som": null
}

var Score: int = 0
var erros: int = 0
var TempoDeJogo_Min: int = 0
var TempoDeJogo_Sec: int = 0
var JogoConcluido: bool = false
var Intro_tocar: bool = true

func _ready() -> void:
	add_child(JsonRequest)
	add_child(ImagemRequest)
	add_child(AudioRequest)
	add_child(AudioSilabaRequest)
	JsonRequest.request_completed.connect(_on_json_request_completed)
	ImagemRequest.request_completed.connect(_on_imagem_request_completed)
	AudioRequest.request_completed.connect(_on_audio_palavra_completed)
	AudioSilabaRequest.request_completed.connect(_on_audio_silaba_completed)

	var url = "http://localhost:8080/api/recursos/palavras?vogal=O&limite=9&tipoColorir=NAO_COLORIR&quantImagens=4"
	var headers = ["Content-Type: application/json"]
	JsonRequest.request(url, headers, HTTPClient.METHOD_GET)


func _on_json_request_completed(_result: int, _response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var json_string = body.get_string_from_utf8()
	var json = JSON.parse_string(json_string)
	array_dicionario = json
	request_imagem()


func request_imagem() -> void:
	if index == array_dicionario.size():
		return
	array_dicionario_imagens = array_dicionario[index].imagens
	if cont_img < array_dicionario_imagens.size():
		ImagemRequest.request(array_dicionario_imagens[cont_img].imagem)
		cont_img += 1


func _on_imagem_request_completed(_result: int, _response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var image = Image.new()
	image.load_png_from_buffer(body)
	var texture = ImageTexture.create_from_image(image)
	texturas.append(texture)

	if cont_img < array_dicionario_imagens.size():
		request_imagem()
	else:
		AudioRequest.request(array_dicionario[index].som)


func _on_audio_palavra_completed(_result: int, _response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	audio_palavra = AudioStreamOggVorbis.load_from_buffer(body)
	# Começa a baixar áudios das sílabas
	cont_silaba = 0
	audios_silabas.clear()
	request_audio_silaba()


func request_audio_silaba() -> void:
	var silabas = array_dicionario[index].silabas
	if cont_silaba < silabas.size():
		AudioSilabaRequest.request(silabas[cont_silaba].som)
		cont_silaba += 1
	else:
		cria_dicionario()


func _on_audio_silaba_completed(_result: int, _response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var audio_silaba = AudioStreamOggVorbis.load_from_buffer(body)
	audios_silabas.append(audio_silaba)
	request_audio_silaba()


func cria_dicionario() -> void:
	# Monta silabas com audio já baixado
	var silabas_raw = array_dicionario[index].silabas
	var silabas_completas = []
	for i in range(silabas_raw.size()):
		silabas_completas.append({
			"posicao": silabas_raw[i].posicao,
			"silaba": silabas_raw[i].silaba,
			"som": audios_silabas[i]
		})

	dicionario = {
		"palavra": array_dicionario[index].palavra,
		"silabas": silabas_completas,
		"imagens": texturas.duplicate(),
		"som": audio_palavra
	}
	array_palavras.append(dicionario)

	index += 1
	print(index)

	cont_img = 0
	texturas.clear()
	audio_palavra = null
	request_imagem()


func embaralhar() -> void:
	array_palavras.shuffle()
	array_imagens = array_palavras[0].imagens
	array_imagens.shuffle()
