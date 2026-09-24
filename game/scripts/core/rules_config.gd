@tool
class_name RulesConfig
extends Resource
## Oyunun bütün sayıları tek yerde. Godot'da res://data/rules.tres dosyasına
## tıkla, Inspector'dan değiştir; kod değiştirmeye gerek yok.
## Değerler web sürümündeki (v1.0-web) klasik partiden birebir alındı.

@export_group("Süreler (saniye)")
## Tur açılış kartının ekranda kalma süresi
@export var intro_s := 5.0
## Kategori halatı süresi
@export var tug_s := 8.0
## Cevap süresi, tur 1 ve 2
@export var answer_s := 12.0
## Cevap süresi, tur 3 (can turu)
@export var answer_final_s := 11.0
## Doğru cevabın gösterildiği süre
@export var reveal_s := 3.2
## Tur arası sıralama kartı
@export var standings_s := 5.0
## Ödül (soygun/sabotaj) seçme süresi
@export var reward_pick_s := 9.0

@export_group("Puanlama (tur 1-2)")
## Doğru cevap merdiveni: 1. doğru, 2. doğru, 3. doğru, 4.+ doğru
@export var combo_steps: PackedInt32Array = [250, 250, 500, 750]
## Tur 1 ve 2'nin soru zorlukları (d1 kolay, d2 orta, d3 zor)
@export var round1_tiers: PackedStringArray = ["d1", "d1", "d2", "d3"]
@export var round2_tiers: PackedStringArray = ["d1", "d2", "d2", "d3"]

@export_group("Güç turu (tur 2)")
## Soygunda çalınan puan
@export var siphon := 400
## Sabotaj süresi: kaç soru boyunca etkili
@export var debuff_questions := 1
## Kurşun ayakkabı: hız çarpanı
@export var lead_speed := 0.5
## Buz pisti: ivme çarpanı (düşük = kaygan)
@export var ice_accel := 0.22
## Dev kafa: denge çarpanı (düşük = kolay devrilir)
@export var bighead_balance := 0.35

@export_group("Son ayakta kalan (tur 3)")
## En fazla soru
@export var final_max_questions := 16
## Formülün kalibre edildiği başlangıç canı
@export var final_start_hp := 4500
## Can tabanı: liderin puanının bu oranı…
@export var hp_floor_ratio := 0.35
## …ama en az bu kadar
@export var hp_floor_min := 1000
## Ceza(t, N) = (base + per_q·t) · (1 + num/N)
@export var penalty_base := 100
@export var penalty_per_q := 40
@export var penalty_num := 2.0
## Bedel ölçeği sınırları (masanın ortalama canı / başlangıç canı)
@export var stake_scale_min := 0.3
@export var stake_scale_max := 2.5
## Tur 3 soru zorluğu: ilk kaç soru orta (sonrası zor)
@export var final_medium_count := 3

## Tur 3 bedeli: web sürümündeki roundPenalty(t, n) ile aynı.
func round_penalty(t: int, n: int) -> int:
	return int(round((penalty_base + penalty_per_q * max(1, t)) * (1.0 + penalty_num / max(1, n))))

## Verilen canın kaç soruda biteceği (denge kontrolü için)
func penalty_rounds(start_hp: int, n: int) -> int:
	var hp := start_hp
	var t := 0
	while hp > 0 and t < 60:
		t += 1
		hp -= round_penalty(t, n)
	return t

func combo_gain(combo: int) -> int:
	if combo <= 0:
		return 0
	return combo_steps[min(combo, combo_steps.size()) - 1]

func tier_for(round_no: int, index: int) -> String:
	if round_no == 3:
		return "d2" if index < final_medium_count else "d3"
	var spec := round1_tiers if round_no == 1 else round2_tiers
	return spec[min(index, spec.size() - 1)]

func questions_in(round_no: int) -> int:
	if round_no == 3:
		return final_max_questions
	return (round1_tiers if round_no == 1 else round2_tiers).size()
