extends Node

var audio_player: AudioStreamPlayer

func _ready() -> void:
	# Criar dinamicamente o reprodutor de música de fundo
	audio_player = AudioStreamPlayer.new()
	audio_player.bus = "Master" # Futuramente, criaremos um bus pra "Music" separado
	audio_player.process_mode = Node.PROCESS_MODE_ALWAYS # Nunca para, mesmo com o jogo em pause
	add_child(audio_player)

func play_music(stream: AudioStream, loop: bool = true) -> void:
	# Não reiniciar se a mesma música já estiver tocando
	if audio_player.stream == stream and audio_player.playing:
		return
		
	# Certificar que faz loop nativo
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3 or stream is AudioStreamWAV:
		_set_stream_loop(stream, loop)

	audio_player.stream = stream
	audio_player.play()

func stop_music() -> void:
	audio_player.stop()
	
func _set_stream_loop(stream: AudioStream, loop: bool) -> void:
	# Lógica interna para habilitar loop nativo dependendo do formato de codec
	if stream is AudioStreamOggVorbis:
		stream.loop = loop
	elif stream is AudioStreamMP3:
		stream.loop = loop
	elif stream is AudioStreamWAV:
		if loop:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_end = stream.get_data().size() # Loop até o fim
		else:
			stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
