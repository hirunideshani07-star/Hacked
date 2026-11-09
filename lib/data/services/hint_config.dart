/// Hint reward / lifetime-unlock settings. Change the values here.
class HintConfig {
  HintConfig._();

  /// Every time a player's leaderboard score passes another multiple of this,
  /// they get [hintsPerReward] hints. (400, 800, 1200, ...)
  static const int pointsPerReward = 400;
  static const int hintsPerReward = 3;

  /// Lifetime (unlimited) hints, sold separately.
  static const int lifetimePriceRs = 100;

  /// !!! CHANGE THIS before you release the app !!!
  /// Long random secret that only YOU know. Each buyer's unlock code is
  /// calculated from this + their Device ID (tools/make_code.py), so a code
  /// works on ONE phone only. Never share this value or commit the real one
  /// to a public repo.
  static const String licenseSecret = '7GjM6Gs6TDSmdunpK1uorVMqTYOuVPn4';

  /// Your WhatsApp number (international format, digits only).
  static const String whatsappNumber = '94783756055';
  static const String whatsappDisplay = '+94 78 375 6055';

  /// Wrong-code protection.
  static const int maxWrongTries = 5;
  static const int lockSeconds = 60;
}
