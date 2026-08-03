/// Photo asset for each scannable object, keyed by its English label
/// (case-insensitive). Mirrors mobilenetv3_classes.json — the 30 classes the
/// model can recognise — so the scan screen's sample list and the
/// recognition result screen's big icon always agree with each other.
///
/// These are full-bleed photos (not transparent icon cutouts), so callers
/// must crop them (e.g. `ClipRRect` + `BoxFit.cover`) rather than laying them
/// over a background with `BoxFit.contain`.
const Map<String, String> objectIcons = {
  'book': 'assets/classes/book_v2.png',
  'pen': 'assets/classes/pen_v2.png',
  'ruler': 'assets/classes/ruler_v2.png',
  'backpack': 'assets/classes/backpack_v2.png',
  'bottle': 'assets/classes/bottle_v2.png',
  'cup': 'assets/classes/cup_v2.png',
  'spoon': 'assets/classes/spoon_v2.png',
  'fork': 'assets/classes/fork_v2.png',
  'knife': 'assets/classes/knife_v2.png',
  'plate': 'assets/classes/plate_v2.png',
  'bowl': 'assets/classes/bowl_v2.png',
  'remote control': 'assets/classes/remotecontrol_v2.png',
  'apple': 'assets/classes/apple_v2.png',
  'banana': 'assets/classes/banana_v2.png',
  'orange': 'assets/classes/orange_v2.png',
  'bread': 'assets/classes/bread_v2.png',
  'ball': 'assets/classes/ball_v2.png',
  'chair': 'assets/classes/chair_v2.png',
  'table': 'assets/classes/table_v2.png',
  'clock': 'assets/classes/clock_v2.png',
  'lamp': 'assets/classes/lamp_v2.png',
  'glasses': 'assets/classes/glasses_v2.png',
  'keyboard': 'assets/classes/keyboard_v2.png',
  'laptop': 'assets/classes/laptop_v2.png',
  'mobile phone': 'assets/classes/mobile_phone_v2.png',
  'scissors': 'assets/classes/scissor_v2.png',
  'shoe': 'assets/classes/shoe_v2.png',
  'teddy bear': 'assets/classes/teddybear_v2.png',
  'toothbrush': 'assets/classes/toothbrush_v2.png',
  'umbrella': 'assets/classes/umbrella_v2.png',
};

/// Icon for [label], falling back to a generic box for anything not in the
/// scannable set (or an empty/unrecognised label).
String objectIconFor(String label) =>
    objectIcons[label.trim().toLowerCase()] ?? 'assets/icons/box.png';
