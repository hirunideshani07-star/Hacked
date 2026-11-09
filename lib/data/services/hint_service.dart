import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pipes/data/services/hint_config.dart';

enum UnlockResult { success, wrong, locked }

/// Keeps the hint balance.
///  * Every [HintConfig.pointsPerReward] leaderboard points => +3 hints.
///  * Lifetime unlock (paid) => unlimited hints, but only on the phone the
///    unlock code was made for (code = HMAC(secret, deviceId)).
class HintService extends ChangeNotifier {
  static const String _boxName = 'pipes_settings';
  static const String _codeKey = 'hint_lifetime_code';
  static const String _fallbackIdKey = 'device_fallback_id';
  static const MethodChannel _channel = MethodChannel('mathra/device');

  Box get _box => Hive.box(_boxName);

  int _wrongTries = 0;
  DateTime? _lockedUntil;
  String _deviceId = '';
  bool _lifetime = false;

  /// Short ID shown to the player (e.g. "A1B2C-3D4E5"). They send it to you.
  String get deviceId => _deviceId;

  /// Must be called once at startup (after Hive is open).
  Future<void> init() async {
    String raw = '';
    try {
      raw = (await _channel.invokeMethod<String>('androidId')) ?? '';
    } catch (_) {}
    if (raw.isEmpty) {
      // Fallback: random id kept in local storage (changes if app data is
      // cleared / reinstalled).
      var fb = _box.get(_fallbackIdKey) as String?;
      if (fb == null) {
        final r = Random.secure();
        fb = List.generate(16, (_) => r.nextInt(16).toRadixString(16)).join();
        await _box.put(_fallbackIdKey, fb);
      }
      raw = fb;
    }
    final h = sha256.convert(utf8.encode('MATHRA-DEVICE|$raw')).toString();
    final s = h.substring(0, 10).toUpperCase();
    _deviceId = '${s.substring(0, 5)}-${s.substring(5)}';

    final saved = _box.get(_codeKey) as String?;
    _lifetime = saved != null && _codeMatches(saved);
  }

  static String _normalize(String s) =>
      s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  String _expectedCode() {
    final mac = Hmac(sha256, utf8.encode(HintConfig.licenseSecret));
    final d = mac
        .convert(utf8.encode('MATHRA-LICENSE|${_normalize(_deviceId)}'))
        .toString()
        .substring(0, 12)
        .toUpperCase();
    return d;
  }

  bool _codeMatches(String input) {
    final a = _normalize(input);
    final b = _expectedCode();
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  bool get isLifetime => _lifetime;

  /// Hints this player can use right now.
  int balanceFor(String name) {
    if (name.trim().isEmpty) return 0;
    return (_box.get(_k('hint_bal', name), defaultValue: 0) as int);
  }

  String _k(String prefix, String name) =>
      '${prefix}_${name.trim().toLowerCase()}';

  int _setsGiven(String name) =>
      (_box.get(_k('hint_sets', name), defaultValue: 0) as int);

  /// Points still needed for the next free hints.
  int pointsToNext(int score) =>
      HintConfig.pointsPerReward - (score % HintConfig.pointsPerReward);

  /// Call after the score changes. Returns how many hints were just granted.
  /// "Sets given" is never reset, so deleting & re-adding a name can't
  /// farm the same reward twice.
  Future<int> awardForScore(String name, int score) async {
    if (name.trim().isEmpty) return 0;
    final earnedSets = score ~/ HintConfig.pointsPerReward;
    final given = _setsGiven(name);
    if (earnedSets <= given) return 0;
    final granted = (earnedSets - given) * HintConfig.hintsPerReward;
    await _box.put(_k('hint_sets', name), earnedSets);
    await _box.put(_k('hint_bal', name), balanceFor(name) + granted);
    notifyListeners();
    return granted;
  }

  /// Uses one hint. Lifetime players never lose any. False = none left.
  Future<bool> consume(String name) async {
    if (isLifetime) return true;
    final bal = balanceFor(name);
    if (bal <= 0) return false;
    await _box.put(_k('hint_bal', name), bal - 1);
    notifyListeners();
    return true;
  }

  /// Gives one hint back (used if a hint could not be shown).
  Future<void> refund(String name) async {
    if (isLifetime || name.trim().isEmpty) return;
    await _box.put(_k('hint_bal', name), balanceFor(name) + 1);
    notifyListeners();
  }

  int get lockSecondsLeft {
    final until = _lockedUntil;
    if (until == null) return 0;
    final left = until.difference(DateTime.now()).inSeconds + 1;
    return left > 0 ? left : 0;
  }

  Future<UnlockResult> tryUnlock(String code) async {
    if (lockSecondsLeft > 0) return UnlockResult.locked;
    if (_codeMatches(code)) {
      _wrongTries = 0;
      _lockedUntil = null;
      _lifetime = true;
      await _box.put(_codeKey, _normalize(code));
      notifyListeners();
      return UnlockResult.success;
    }
    _wrongTries++;
    if (_wrongTries >= HintConfig.maxWrongTries) {
      _wrongTries = 0;
      _lockedUntil =
          DateTime.now().add(const Duration(seconds: HintConfig.lockSeconds));
      return UnlockResult.locked;
    }
    return UnlockResult.wrong;
  }
}
