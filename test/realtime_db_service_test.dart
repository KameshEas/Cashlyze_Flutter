import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_database/firebase_database.dart';

void main() {
  group('ServerValue conversion', () {
    test('should convert ServerValue.timestamp to REST API format', () {
      final convertServerValues = _createConvertFunction();
      
      final data = {
        'title': 'Test Transaction',
        'amount': 100.0,
        'created_at_ms': ServerValue.timestamp,
        'updated_at_ms': ServerValue.timestamp,
      };
      
      final converted = convertServerValues(data);
      
      expect(converted['title'], equals('Test Transaction'));
      expect(converted['amount'], equals(100.0));
      expect(converted['created_at_ms'], equals({'.sv': 'timestamp'}));
      expect(converted['updated_at_ms'], equals({'.sv': 'timestamp'}));
    });

    test('should handle nested maps with ServerValue', () {
      final convertServerValues = _createConvertFunction();
      
      final data = {
        'user': {
          'name': 'John',
          'timestamp': ServerValue.timestamp,
        },
        'created_at_ms': ServerValue.timestamp,
      };
      
      final converted = convertServerValues(data);
      
      expect(converted['user']['name'], equals('John'));
      expect(converted['user']['timestamp'], equals({'.sv': 'timestamp'}));
      expect(converted['created_at_ms'], equals({'.sv': 'timestamp'}));
    });

    test('should handle lists with ServerValue', () {
      final convertServerValues = _createConvertFunction();
      
      final data = {
        'items': [
          {'id': 1, 'ts': ServerValue.timestamp},
          {'id': 2, 'ts': ServerValue.timestamp},
        ],
        'created_at_ms': ServerValue.timestamp,
      };
      
      final converted = convertServerValues(data);
      
      expect((converted['items'] as List)[0]['id'], equals(1));
      expect((converted['items'] as List)[0]['ts'], equals({'.sv': 'timestamp'}));
      expect((converted['items'] as List)[1]['id'], equals(2));
      expect((converted['items'] as List)[1]['ts'], equals({'.sv': 'timestamp'}));
    });

    test('should leave regular values unchanged', () {
      final convertServerValues = _createConvertFunction();
      
      final data = {
        'title': 'Test',
        'amount': 100.5,
        'active': true,
        'tags': ['tag1', 'tag2'],
        'notes': null,
      };
      
      final converted = convertServerValues(data);
      
      expect(converted['title'], equals('Test'));
      expect(converted['amount'], equals(100.5));
      expect(converted['active'], equals(true));
      expect(converted['tags'], equals(['tag1', 'tag2']));
      expect(converted['notes'], isNull);
    });
  });
}

/// Create the conversion function (same logic as in RealtimeDbService)
Function _createConvertFunction() {
  return (Map<String, dynamic> data) {
    return data.map((key, value) {
      if (value is ServerValue) {
        return MapEntry(key, {'.sv': 'timestamp'});
      } else if (value is Map<String, dynamic>) {
        return MapEntry(key, _createConvertFunction()(value));
      } else if (value is List) {
        return MapEntry(key, value.map((item) {
          if (item is ServerValue) {
            return {'.sv': 'timestamp'};
          } else if (item is Map<String, dynamic>) {
            return _createConvertFunction()(item);
          }
          return item;
        }).toList());
      }
      return MapEntry(key, value);
    });
  };
}
