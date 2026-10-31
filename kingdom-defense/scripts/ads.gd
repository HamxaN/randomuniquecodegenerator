extends Node
## AdMob through the Poing Studios plugin when the build includes it (Android
## release and CI builds); otherwise rewarded ads simply grant their reward so the
## game stays playable on desktop and in tests.
##
## Unit IDs default to Google's public test IDs. Release builds replace them from
## the KINGDOM_ADMOB_* secrets (see README.md).

const API := "res://addons/admob/gdscript/src/api/"
const BANNER_ID := "ca-app-pub-3940256099942544/6300978111"
const INTERSTITIAL_ID := "ca-app-pub-3940256099942544/1033173712"
const REWARDED_ID := "ca-app-pub-3940256099942544/5224354917"
## Minimum gap between interstitials, and matches before the first one.
const INTERSTITIAL_GAP_MS := 150000
const GRACE_MATCHES := 2

var available := false
var _banner: Object
var _interstitial: Object
var _rewarded: Object
var _last_interstitial := -INTERSTITIAL_GAP_MS
var _matches := 0
var _pending_reward: Callable


func _ready() -> void:
	available = OS.get_name() == "Android" and Engine.has_singleton("PoingGodotAdMob") \
		and ResourceLoader.exists(API + "MobileAds.gd")
	if not available:
		return
	_script("MobileAds").initialize()
	_load_interstitial()
	_load_rewarded()


func _script(name: String) -> Script:
	var path := API + name + ".gd"
	if not ResourceLoader.exists(path):
		path = API + "core/" + name + ".gd"
	if not ResourceLoader.exists(path):
		path = API + "listeners/" + name + ".gd"
	return load(path)


func _request() -> Object:
	return _script("AdRequest").new()


func show_banner() -> void:
	if not available:
		return
	if _banner == null:
		var size: Object = _script("AdSize").BANNER
		var pos: Object = _script("AdPosition").BOTTOM
		_banner = _script("AdView").new(_id("banner", BANNER_ID), size, pos)
		_banner.load_ad(_request())
	else:
		_banner.show()


func hide_banner() -> void:
	if _banner != null:
		_banner.hide()


## Called after each match; shows an interstitial when enough time has passed.
func match_finished() -> void:
	_matches += 1
	if not available or _interstitial == null or _matches <= GRACE_MATCHES:
		return
	if Time.get_ticks_msec() - _last_interstitial < INTERSTITIAL_GAP_MS:
		return
	_last_interstitial = Time.get_ticks_msec()
	_interstitial.show()
	_interstitial = null
	_load_interstitial()


func rewarded_ready() -> bool:
	return not available or _rewarded != null


## Shows a rewarded ad and calls [param on_reward] if the player watched it.
func show_rewarded(on_reward: Callable) -> void:
	if not available:
		on_reward.call()
		return
	if _rewarded == null:
		_load_rewarded()
		return
	_pending_reward = on_reward
	var listener: Object = _script("OnUserEarnedRewardListener").new()
	listener.on_user_earned_reward = func(_item: Variant) -> void:
		if _pending_reward.is_valid():
			_pending_reward.call_deferred()
		_pending_reward = Callable()
	_rewarded.show(listener)
	_rewarded = null
	_load_rewarded()


func _load_interstitial() -> void:
	var cb: Object = _script("InterstitialAdLoadCallback").new()
	cb.on_ad_loaded = func(ad: Variant) -> void: _interstitial = ad
	_script("InterstitialAdLoader").new().load(_id("interstitial", INTERSTITIAL_ID), _request(), cb)


func _load_rewarded() -> void:
	var cb: Object = _script("RewardedAdLoadCallback").new()
	cb.on_ad_loaded = func(ad: Variant) -> void: _rewarded = ad
	_script("RewardedAdLoader").new().load(_id("rewarded", REWARDED_ID), _request(), cb)


## Real unit IDs are written into res://ad_units.cfg by the release workflow.
func _id(kind: String, fallback: String) -> String:
	var cfg := ConfigFile.new()
	if cfg.load("res://ad_units.cfg") == OK:
		return str(cfg.get_value("admob", kind, fallback))
	return fallback
