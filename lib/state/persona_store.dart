import 'package:flutter/foundation.dart';
import 'package:assence/data/seed_data.dart';
import 'package:assence/models/persona.dart';
import 'package:assence/services/local_store.dart';
import 'package:assence/utils/format.dart';

/// 기본 페르소나 4인 + 사용자가 만든 커스텀 캐릭터.
class PersonaStore extends ChangeNotifier {
  static const String _storageKey = 'custom_personas';

  final LocalStore _local;
  final List<Persona> _custom = <Persona>[];

  PersonaStore(this._local) {
    final Object? saved = _local.readJson(_storageKey);
    if (saved is List<dynamic>) {
      _custom.addAll(saved.map(
          (dynamic json) => Persona.fromJson(json as Map<String, dynamic>)));
    }
  }

  List<Persona> get all => <Persona>[...seedPersonas, ..._custom];

  Persona? byId(String id) {
    for (final Persona persona in all) {
      if (persona.id == id) return persona;
    }
    return null;
  }

  Persona addCustom({
    required String name,
    required String prompt,
    String bio = '',
  }) {
    final Persona persona = Persona(
      id: newId('custom'),
      name: name,
      handle: name,
      bio: bio.isEmpty ? '사용자 정의 캐릭터' : bio,
      prompt: prompt,
      isCustom: true,
    );
    _custom.add(persona);
    _save();
    notifyListeners();
    return persona;
  }

  void removeCustom(String id) {
    _custom.removeWhere((Persona p) => p.id == id);
    _save();
    notifyListeners();
  }

  Future<void> _save() => _local.writeJson(
      _storageKey, _custom.map((Persona p) => p.toJson()).toList());
}
