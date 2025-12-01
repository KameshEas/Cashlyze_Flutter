import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();
  _GoogleAuthClient(this._headers);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}

class DriveBackupService {
  final GoogleSignIn _signIn;

  DriveBackupService()
    : _signIn = GoogleSignIn(scopes: <String>[drive.DriveApi.driveFileScope]);

  Future<drive.DriveApi> _api() async {
    var account = await _signIn.signInSilently();
    account ??= await _signIn.signIn();
    if (account == null) {
      throw StateError('Google Sign-In failed');
    }
    final headers = await account.authHeaders;
    final client = _GoogleAuthClient(headers);
    return drive.DriveApi(client);
  }

  Future<String> uploadJson({
    required String filename,
    required String json,
  }) async {
    final api = await _api();
    final q = "name='$filename' and trashed=false";
    final list = await api.files.list(q: q, spaces: 'drive');
    final media = drive.Media(
      Stream.value(Uint8List.fromList(utf8.encode(json))),
      json.length,
    );
    if (list.files != null && list.files!.isNotEmpty) {
      final fileId = list.files!.first.id!;
      await api.files.update(
        drive.File(name: filename, mimeType: 'application/json'),
        fileId,
        uploadMedia: media,
      );
      return fileId;
    } else {
      final created = await api.files.create(
        drive.File(name: filename, mimeType: 'application/json'),
        uploadMedia: media,
      );
      return created.id!;
    }
  }

  Future<String?> downloadJson({required String filename}) async {
    final api = await _api();
    final q = "name='$filename' and trashed=false";
    final list = await api.files.list(q: q, spaces: 'drive');
    if (list.files == null || list.files!.isEmpty) return null;
    final fileId = list.files!.first.id!;
    final media =
        await api.files.get(
              fileId,
              downloadOptions: drive.DownloadOptions.fullMedia,
            )
            as drive.Media;
    final bytes = await media.stream.expand((x) => x).toList();
    return utf8.decode(bytes);
  }
}

final driveBackupServiceProvider = Provider<DriveBackupService>(
  (ref) => DriveBackupService(),
);
