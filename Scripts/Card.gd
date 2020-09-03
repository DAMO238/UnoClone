extends TextureButton

var colour
var number
var index : int = -1

func init(colour, number):
	self.colour = colour
	self.number = number
	var card_name = String(colour) + "-" + String(number) + ".png"
	self.texture_normal = load("res://Images/Cards/" + card_name)


func _on_Card_pressed():
	get_node("/root/Main").play_card(index)
