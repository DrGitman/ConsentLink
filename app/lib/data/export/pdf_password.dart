// data/export/pdf_password.dart
// Password protection for exported PDFs: the PDF standard security handler,
// revision 3 (128 bit RC4, PDF 1.4+). Every PDF reader asks for the password
// before showing anything; text, images and signatures are all encrypted.
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pdf/pdf.dart';
// PdfString and PdfNum are not exported by package:pdf/pdf.dart.
// ignore: implementation_imports
import 'package:pdf/src/priv.dart';

const _padding = <int>[
  0x28, 0xBF, 0x4E, 0x5E, 0x4E, 0x75, 0x8A, 0x41, //
  0x64, 0x00, 0x4E, 0x56, 0xFF, 0xFA, 0x01, 0x08,
  0x2E, 0x2E, 0x00, 0xB6, 0xD0, 0x68, 0x3E, 0x80,
  0x2F, 0x0C, 0xA9, 0xFE, 0x64, 0x53, 0x69, 0x7A,
];

/// All permissions (print, copy, edit) once the password is given.
const _permissions = -4;

/// Encrypts [document] with [password]. Set it before saving:
/// `doc.document.encryption = PdfPasswordEncryption(doc.document, pw)`.
class PdfPasswordEncryption extends PdfEncryption {
  PdfPasswordEncryption(super.pdfDocument, String password) {
    final random = Random.secure();
    final owner = List<int>.generate(32, (_) => random.nextInt(256));
    final user = padPassword(password);
    final id = pdfDocument.documentID;
    _owner = ownerEntry(owner, user);
    _key = fileKey(user, _owner, id);
    final userEntry = userEntryFor(_key, id);
    params['/Filter'] = const PdfName('/Standard');
    params['/V'] = const PdfNum(2);
    params['/R'] = const PdfNum(3);
    params['/Length'] = const PdfNum(128);
    params['/P'] = const PdfNum(_permissions);
    params['/O'] = PdfString(
      _owner,
      format: PdfStringFormat.binary,
      encrypted: false,
    );
    params['/U'] = PdfString(
      userEntry,
      format: PdfStringFormat.binary,
      encrypted: false,
    );
  }

  late final Uint8List _owner;
  late final Uint8List _key;

  @override
  Uint8List encrypt(Uint8List input, PdfObjectBase object) {
    final seed = <int>[
      ..._key,
      object.objser & 0xff,
      (object.objser >> 8) & 0xff,
      (object.objser >> 16) & 0xff,
      object.objgen & 0xff,
      (object.objgen >> 8) & 0xff,
    ];
    final key = md5.convert(seed).bytes.sublist(0, 16);
    return rc4(key, input);
  }

  /// The password as the 32 bytes the standard handler uses (Algorithm 2).
  static Uint8List padPassword(String password) {
    final bytes = latin1.encode(
      String.fromCharCodes(password.runes.map((r) => r > 255 ? 0x3f : r)),
    );
    return Uint8List.fromList([...bytes.take(32), ..._padding].sublist(0, 32));
  }

  /// The /O entry (Algorithm 3, revision 3).
  static Uint8List ownerEntry(List<int> ownerPadded, Uint8List userPadded) {
    var hash = md5.convert(ownerPadded).bytes;
    for (var i = 0; i < 50; i++) {
      hash = md5.convert(hash).bytes;
    }
    final key = hash.sublist(0, 16);
    var out = rc4(key, userPadded);
    for (var i = 1; i <= 19; i++) {
      out = rc4([for (final b in key) b ^ i], out);
    }
    return out;
  }

  /// The file key (Algorithm 2, revision 3).
  static Uint8List fileKey(
    Uint8List userPadded,
    Uint8List owner,
    List<int> id,
  ) {
    final p = ByteData(4)..setInt32(0, _permissions, Endian.little);
    var hash = md5.convert([
      ...userPadded,
      ...owner,
      ...p.buffer.asUint8List(),
      ...id,
    ]).bytes;
    for (var i = 0; i < 50; i++) {
      hash = md5.convert(hash.sublist(0, 16)).bytes;
    }
    return Uint8List.fromList(hash.sublist(0, 16));
  }

  /// The /U entry (Algorithm 5).
  static Uint8List userEntryFor(Uint8List key, List<int> id) {
    var out = rc4(
      key,
      Uint8List.fromList(md5.convert([..._padding, ...id]).bytes),
    );
    for (var i = 1; i <= 19; i++) {
      out = rc4([for (final b in key) b ^ i], out);
    }
    return Uint8List.fromList([...out, ...List.filled(16, 0)]);
  }
}

/// RC4 stream cipher (the PDF standard handler's cipher).
Uint8List rc4(List<int> key, List<int> data) {
  final s = List<int>.generate(256, (i) => i);
  var j = 0;
  for (var i = 0; i < 256; i++) {
    j = (j + s[i] + key[i % key.length]) & 0xff;
    final t = s[i];
    s[i] = s[j];
    s[j] = t;
  }
  final out = Uint8List(data.length);
  var i = 0;
  j = 0;
  for (var n = 0; n < data.length; n++) {
    i = (i + 1) & 0xff;
    j = (j + s[i]) & 0xff;
    final t = s[i];
    s[i] = s[j];
    s[j] = t;
    out[n] = data[n] ^ s[(s[i] + s[j]) & 0xff];
  }
  return out;
}
