class GameAssets {
  GameAssets._();

  static const String feltBg = 'assets/game/table/felt_bg.png';
  static const String centerPanel = 'assets/game/table/center_panel.png';
  static const String discardSlot = 'assets/game/ui/discard_slot.png';
  static const String drawPile = 'assets/game/ui/draw_pile.png';
  static const String rackHorizontal = 'assets/game/rack/rack_horizontal.png';
  static const String rackVertical = 'assets/game/rack/rack_vertical.png';
  static const String tileBack = 'assets/game/tiles/back/tile_back.png';

  static String tileFront(String key) => 'assets/game/tiles/front/$key.png';
}
