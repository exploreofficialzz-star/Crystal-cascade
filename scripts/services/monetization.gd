class_name Monetization
extends Node

# Production-safe abstraction. It never grants a paid item until a native
# Android/iOS store adapter reports a verified purchase/reward callback.

const PRODUCT_IDS := {
    "remove_ads_day": "remove_ads_day",
    "remove_ads_weekend": "remove_ads_weekend",
    "remove_ads_month": "remove_ads_month",
    "hint_pack_small": "hint_pack_small",
    "hint_pack_large": "hint_pack_large",
    "coin_pack_starter": "coin_pack_starter",
    "mega_pack": "mega_pack"
}

signal purchase_requested(product_id: String)
signal rewarded_requested(reward_type: String)

func request_purchase(product_id: String) -> void:
    if not PRODUCT_IDS.has(product_id):
        return
    purchase_requested.emit(product_id)

func request_rewarded(reward_type: String) -> void:
    rewarded_requested.emit(reward_type)

func deliver_verified_purchase(save: SaveData, product_id: String) -> void:
    match product_id:
        "hint_pack_small": save.add_hints(5)
        "hint_pack_large": save.add_hints(15)
        "coin_pack_starter":
            save.add_coins(500)
            save.add_hints(5)
        "mega_pack":
            save.add_coins(2000)
            save.add_hints(20)
            save.set_remove_ads("weekend", 48 * 60 * 60)
        "remove_ads_day": save.set_remove_ads("day", 24 * 60 * 60)
        "remove_ads_weekend": save.set_remove_ads("weekend", 48 * 60 * 60)
        "remove_ads_month": save.set_remove_ads("month", 30 * 24 * 60 * 60)

func deliver_verified_reward(save: SaveData, reward_type: String) -> void:
    match reward_type:
        "coins": save.add_coins(50)
        "extra_moves": pass
        "hint": save.add_hints(1)
        "life": save.add_life()
