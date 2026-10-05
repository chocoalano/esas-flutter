import 'package:get_storage/get_storage.dart';

/// Device-local preferences and cached display data.
///
/// An interface rather than a bare `GetStorage()` because twelve files
/// constructed their own, which is what makes their owners impossible to unit
/// test — see MED-06 and §31 of the refactoring brief. Injecting this lets a
/// test supply [InMemoryLocalStorage] and never touch a platform channel.
///
/// Not for credentials. Those go to `SecureStore`.
abstract interface class LocalStorage {
  T? read<T>(String key);

  Future<void> write(String key, dynamic value);

  Future<void> remove(String key);

  Future<void> removeAll(Iterable<String> keys);

  bool hasData(String key);
}

class GetStorageLocalStorage implements LocalStorage {
  GetStorageLocalStorage([GetStorage? box]) : _box = box ?? GetStorage();

  final GetStorage _box;

  @override
  T? read<T>(String key) => _box.read<T>(key);

  @override
  Future<void> write(String key, dynamic value) => _box.write(key, value);

  @override
  Future<void> remove(String key) => _box.remove(key);

  @override
  Future<void> removeAll(Iterable<String> keys) async {
    for (final key in keys) {
      await _box.remove(key);
    }
  }

  @override
  bool hasData(String key) => _box.hasData(key);
}

class InMemoryLocalStorage implements LocalStorage {
  InMemoryLocalStorage([Map<String, dynamic>? seed]) : _values = {...?seed};

  final Map<String, dynamic> _values;

  @override
  T? read<T>(String key) => _values[key] as T?;

  @override
  Future<void> write(String key, dynamic value) async => _values[key] = value;

  @override
  Future<void> remove(String key) async => _values.remove(key);

  @override
  Future<void> removeAll(Iterable<String> keys) async {
    for (final key in keys) {
      _values.remove(key);
    }
  }

  @override
  bool hasData(String key) => _values.containsKey(key);
}
