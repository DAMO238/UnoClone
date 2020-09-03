extends Control

var card_res = preload("res://Scenes/Card.tscn")

var peer : NetworkedMultiplayerENet = null
var players = []
var players_to_draw = []
var max_players : int = -1

var deck = []
var discard = []
var hand = []

var shuffle_rng : RandomNumberGenerator = RandomNumberGenerator.new()

func shuffle_deck(deck):
	var shuffled_deck = [] 
	var index_deck = range(deck.size())
	for i in range(deck.size()):
		var x = shuffle_rng.randi()%index_deck.size()
		shuffled_deck.append(deck[index_deck[x]])
		index_deck.remove(x)
	return shuffled_deck

func generate_deck():
	var tmp_deck = []
	for i in [
		Consts.Colours.RED,
		Consts.Colours.GREEN,
		Consts.Colours.YELLOW,
		Consts.Colours.BLUE
	]:
		tmp_deck.append(card_res.instance())
		add_child(tmp_deck.back())
		tmp_deck.back().init(i, Consts.Numbers.ZERO)
		for j in [
			Consts.Numbers.ONE,
			Consts.Numbers.TWO,
			Consts.Numbers.THREE,
			Consts.Numbers.FOUR,
			Consts.Numbers.FIVE,
			Consts.Numbers.SIX,
			Consts.Numbers.SEVEN,
			Consts.Numbers.EIGHT,
			Consts.Numbers.NINE,
			Consts.Numbers.PLUSTWO,
			Consts.Numbers.SWITCH,
			Consts.Numbers.MISS
		]:
			tmp_deck.append(card_res.instance())
			add_child(tmp_deck.back())
			tmp_deck.back().init(i, j)
	for i in range(4):
		tmp_deck.append(card_res.instance())
		add_child(tmp_deck.back())
		tmp_deck.back().init(Consts.Colours.WILD, Consts.Numbers.WILD)
		
		tmp_deck.append(card_res.instance())
		add_child(tmp_deck.back())
		tmp_deck.back().init(Consts.Colours.WILD, Consts.Numbers.PLUSFOUR)
	
	deck = shuffle_deck(tmp_deck)
		

func _on_JoinButton_pressed():
	print("Joining...")
	peer = NetworkedMultiplayerENet.new()
	peer.create_client(String($IPBox.text), int($PortBox.text))
	get_tree().connect("connected_to_server", self, "_connected_to_server")
	get_tree().connect("server_disconnected", self, "_server_disconnected")
	get_tree().connect("connection_failed", self, "_connection_failed")
	get_tree().set_network_peer(peer)



func _on_HostButton_pressed():
	print("Hosting...")
	peer = NetworkedMultiplayerENet.new()
	peer.refuse_new_connections = false
	max_players = int($PlayersBox.text)
	peer.create_server(int($PortBox2.text), max_players)
	get_tree().connect("network_peer_connected", self, "_peer_connected")
	get_tree().connect("network_peer_disconnected", self, "_peer_disconnected")
	get_tree().set_network_peer(peer)
	players.append(peer.get_unique_id())
	
	
func _peer_connected(id : int):
	print("Player connected with id " + String(id))
	players.append(id)
	if len(players) == max_players:
		start()

func _peer_disconnected(id : int):
	print("Player disconnected with id " + String(id))

func _connected_to_server():
	print("Connected to server")

func _server_disconnected():
	print("Server disconnected")

func _connection_failed():
	print("Connection failed")

func start():
	players_to_draw = players
	shuffle_rng.randomize()
	rpc("r_set_shuffle_seed", shuffle_rng.get_seed())
	generate_deck()
	draw_hand() # generate our hand
	h_draw_hand() # generate everyone elses hand

remote func r_set_shuffle_seed(r_seed):
	shuffle_rng.set_seed(r_seed)
	generate_deck()

func draw_card():
	var new_card = deck.pop_back()
	if new_card == null:
		reshuffle()
		draw_card()
	else:
		hand.append(new_card)
		rpc("remove_card")
		update_hand_visuals()
		update_hand_indices()

func reshuffle():
	deck = shuffle_deck(discard)
	discard = []
	turn_top_card()

func update_hand_visuals():
	for child in $GridContainer.get_children():
		child.raise()
		child.visible = false
	for card in hand:
		if card.get_parent():
			card.get_parent().remove_child(card)
		$GridContainer.add_child(card)

		card.visible = true

remote func remove_card():
	deck.pop_back().queue_free()

remote func add_card(colour, number):
	discard.append(card_res.instance())
	add_child(discard.back())
	discard.back().init(colour, number)
	update_discard_visuals()

func draw_hand():
	for i in range(7):
		draw_card()

remote func r_draw_hand():
	draw_hand()
	rpc_id(1, "h_draw_hand")

remote func h_draw_hand():
	var next = players_to_draw.pop_back()
	if next == null:
		turn_top_card()
		return
	if next == 1:
		h_draw_hand()
		return
	rpc_id(next, "r_draw_hand")

func turn_top_card():
	var card = deck.pop_back()
	discard.append(card)
	if card.get_parent():
		card.get_parent().remove_child(card)
	add_child(card)
	rpc("add_card", card.colour, card.number)
	update_discard_visuals()

func update_discard_visuals():
	for card in $Discard.get_children():
		card.raise()
		card.visible = false
	var card = discard.back()
	if card.get_parent():
		card.get_parent().remove_child(card)
	$Discard.add_child(card)
	reset_margins(card)
	card.visible = true

func update_hand_indices():
	for i in range(len(hand)):
		hand[i].index = i

func play_card(index : int):
	var card = hand[index]
	if card.index == -1:
		return
	card.index = -1
	hand.remove(index)
	discard.append(card)
	update_discard_visuals()
	update_hand_visuals()
	update_hand_indices()
	rpc("add_card", card.colour, card.number)

func reset_margins(node : Control):
	node.margin_bottom = 0
	node.margin_left = 0
	node.margin_right = 0
	node.margin_top = 0


func _on_DrawButton_pressed():
	draw_card()
