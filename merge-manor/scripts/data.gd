class_name GameData
## Merge chains, generators, the rooms of the manor and their renovation
## steps, orders and energy. Plain data and maths for the board and the tests.

const COLS := 7
const ROWS := 6
const MAX_ENERGY := 60
const ENERGY_EVERY := 20.0     # seconds per energy point
const ORDER_SLOTS := 3

## Each chain: names and furniture models from level 1 upwards.
const CHAINS := {
	"cozy": {"name": "Cosy seats", "models": ["pillow_A", "pillow_B", "chair_A", "armchair", "armchair_pillows", "couch", "couch_pillows"],
		"names": ["Pillow", "Plump Pillow", "Chair", "Armchair", "Cosy Armchair", "Sofa", "Grand Sofa"], "color": Color("e8a0b0")},
	"books": {"name": "Books", "models": ["book_single", "book_set", "shelf_A_small", "shelf_B_small_decorated", "shelf_B_large_decorated"],
		"names": ["Book", "Book Set", "Little Shelf", "Book Nook", "Library Shelf"], "color": Color("c08a5a")},
	"plants": {"name": "Plants", "models": ["cactus_small_A", "cactus_small_B", "cactus_medium_A", "cactus_medium_B"],
		"names": ["Seedling", "Cactus", "Potted Cactus", "Big Cactus"], "color": Color("7ac06a")},
	"decor": {"name": "Keepsakes", "models": ["pictureframe_standing_A", "pictureframe_standing_B", "lamp_table", "lamp_standing"],
		"names": ["Photo", "Family Photo", "Table Lamp", "Floor Lamp"], "color": Color("f0c860")},
	"art": {"name": "Paintings", "models": ["pictureframe_small_C", "pictureframe_small_A", "pictureframe_small_B", "pictureframe_medium",
		"pictureframe_large_A", "pictureframe_large_B"],
		"names": ["Sketch", "Small Print", "Postcard Frame", "Painting", "Portrait", "Masterpiece"], "color": Color("8ab0e0")},
	"rugs": {"name": "Rugs", "models": ["rug_oval_A", "rug_oval_B", "rug_rectangle_A", "rug_rectangle_B", "rug_rectangle_stripes_A",
		"rug_rectangle_stripes_B"], "names": ["Doormat", "Oval Rug", "Rug", "Fine Rug", "Striped Rug", "Grand Carpet"],
		"color": Color("d07060")},
	"wood": {"name": "Woodwork", "models": ["chair_stool_wood", "chair_A_wood", "chair_B_wood", "table_small", "table_low", "table_medium",
		"table_medium_long"], "names": ["Stool", "Wooden Chair", "Carved Chair", "Side Table", "Coffee Table", "Table", "Dining Table"],
		"color": Color("b07840")},
	"beds": {"name": "Beds", "models": ["bed_single_A", "bed_single_B", "bed_double_A", "bed_double_B"],
		"names": ["Cot", "Single Bed", "Double Bed", "Four-Poster"], "color": Color("90a0e0")},
	"storage": {"name": "Storage", "models": ["cabinet_small", "cabinet_small_decorated", "cabinet_medium", "cabinet_medium_decorated"],
		"names": ["Crate Cabinet", "Nightstand", "Dresser", "Grand Dresser"], "color": Color("a08870")},
}

const GENERATORS := {
	"box": {"name": "Moving Box", "chains": ["cozy", "books", "art"], "icon": "box"},
	"basket": {"name": "Sewing Basket", "chains": ["rugs", "plants", "decor"], "icon": "basket"},
	"bench": {"name": "Workbench", "chains": ["wood", "beds", "storage"], "icon": "saw"},
}

## The rooms, each with renovation steps: the item placed and its spot in the room.
const ROOMS := [
	{"name": "Living Room", "wall": Color(0.86, 0.78, 0.66), "floor": Color(0.62, 0.42, 0.26), "steps": [
		{"name": "Lay a striped rug", "model": "rug_rectangle_stripes_A", "pos": Vector3(0.2, 0.0, 0.4), "rot": 0.0, "stars": 1},
		{"name": "Bring in the sofa", "model": "couch_pillows", "pos": Vector3(0.2, 0.0, -1.7), "rot": 0.0, "stars": 2},
		{"name": "Add a coffee table", "model": "table_low", "pos": Vector3(0.2, 0.0, 0.5), "rot": 0.0, "stars": 2},
		{"name": "Place a cosy armchair", "model": "armchair_pillows", "pos": Vector3(-2.3, 0.0, 0.6), "rot": PI / 2, "stars": 2},
		{"name": "Light the corner", "model": "lamp_standing", "pos": Vector3(-2.6, 0.0, -2.4), "rot": 0.0, "stars": 2},
		{"name": "Hang a portrait", "model": "pictureframe_large_A", "pos": Vector3(0.2, 2.4, -2.9), "rot": 0.0, "stars": 3},
		{"name": "Fill the library shelf", "model": "shelf_B_large_decorated", "pos": Vector3(-2.95, 1.6, -0.6), "rot": PI / 2, "stars": 3},
		{"name": "A cactus by the window", "model": "cactus_medium_A", "pos": Vector3(2.4, 0.0, -2.3), "rot": 0.0, "stars": 3},
	]},
	{"name": "Bedroom", "wall": Color(0.7, 0.78, 0.9), "floor": Color(0.55, 0.38, 0.28), "steps": [
		{"name": "Lay an oval rug", "model": "rug_oval_B", "pos": Vector3(0.4, 0.0, 0.6), "rot": 0.0, "stars": 2},
		{"name": "Build the four-poster", "model": "bed_double_B", "pos": Vector3(0.4, 0.0, -1.3), "rot": 0.0, "stars": 3},
		{"name": "Add a nightstand", "model": "cabinet_small_decorated", "pos": Vector3(-1.9, 0.0, -2.3), "rot": 0.0, "stars": 2},
		{"name": "A grand dresser", "model": "cabinet_medium_decorated", "pos": Vector3(-2.4, 0.0, 1.0), "rot": PI / 2, "stars": 3},
		{"name": "Hang a painting", "model": "pictureframe_medium", "pos": Vector3(-2.95, 2.2, -0.9), "rot": PI / 2, "stars": 2},
		{"name": "A reading chair", "model": "chair_A", "pos": Vector3(2.2, 0.0, 1.2), "rot": -PI / 3, "stars": 2},
		{"name": "A bedside lamp", "model": "lamp_table", "pos": Vector3(-1.9, 1.62, -2.3), "rot": 0.0, "stars": 3},
	]},
	{"name": "Study", "wall": Color(0.62, 0.72, 0.6), "floor": Color(0.45, 0.32, 0.22), "steps": [
		{"name": "Lay a fine rug", "model": "rug_rectangle_B", "pos": Vector3(0.3, 0.0, 0.3), "rot": 0.0, "stars": 2},
		{"name": "A great dining table", "model": "table_medium_long", "pos": Vector3(0.3, 0.0, 0.2), "rot": 0.0, "stars": 3},
		{"name": "Carved chairs", "model": "chair_B_wood", "pos": Vector3(0.3, 0.0, 1.5), "rot": PI, "stars": 2},
		{"name": "Books on the table", "model": "book_set", "pos": Vector3(0.6, 1.25, 0.1), "rot": 0.3, "stars": 2},
		{"name": "The masterpiece", "model": "pictureframe_large_B", "pos": Vector3(0.3, 2.4, -2.9), "rot": 0.0, "stars": 3},
		{"name": "A floor lamp", "model": "lamp_standing", "pos": Vector3(2.5, 0.0, -2.4), "rot": 0.0, "stars": 3},
		{"name": "A wall of books", "model": "shelf_B_large_decorated", "pos": Vector3(-2.95, 1.6, 0.3), "rot": PI / 2, "stars": 3},
		{"name": "A reading armchair", "model": "armchair", "pos": Vector3(-2.0, 0.0, -1.8), "rot": PI / 4, "stars": 3},
	]},
]


static func item(chain: String, level: int) -> String:
	return "%s:%d" % [chain, level]


static func chain_of(id: String) -> String:
	return id.get_slice(":", 0)


static func level_of(id: String) -> int:
	return int(id.get_slice(":", 1))


static func max_level(chain: String) -> int:
	return (CHAINS[chain]["models"] as Array).size()


static func is_item(id: String) -> bool:
	return id.contains(":") and CHAINS.has(chain_of(id))


static func is_generator(id: String) -> bool:
	return id.begins_with("gen_") and GENERATORS.has(id.trim_prefix("gen_"))


static func model(id: String) -> String:
	return CHAINS[chain_of(id)]["models"][level_of(id) - 1]


static func display_name(id: String) -> String:
	if is_generator(id):
		return GENERATORS[id.trim_prefix("gen_")]["name"]
	return CHAINS[chain_of(id)]["names"][level_of(id) - 1]


## Two items merge if they are the same and not at the top of their chain.
static func can_merge(a: String, b: String) -> bool:
	return is_item(a) and a == b and level_of(a) < max_level(chain_of(a))


static func merged(id: String) -> String:
	return item(chain_of(id), level_of(id) + 1)


## Coins for selling an item, if you need the space.
static func sell_value(id: String) -> int:
	return int(pow(2, level_of(id) - 1))


## An order asks for an item; harder orders (higher levels) pay more stars.
static func order_reward(id: String) -> Dictionary:
	var lv := level_of(id)
	return {"stars": 1 + int(lv >= 4) + int(lv >= 6), "coins": 5 * int(pow(2, lv - 1))}


static func total_steps() -> int:
	var n := 0
	for r in ROOMS:
		n += (r["steps"] as Array).size()
	return n
