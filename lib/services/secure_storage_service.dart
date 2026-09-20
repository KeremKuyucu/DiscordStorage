import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

// Native struct for Windows Data Protection API (DPAPI)
final class _DataBlob extends Struct {
  @Uint32()
  external int cbData;
  external Pointer<Uint8> pbData;
}

typedef _CryptProtectDataNative = Int32 Function(
  Pointer<_DataBlob> pDataIn,
  Pointer<Utf16> szDataDescr,
  Pointer<_DataBlob> pOptionalEntropy,
  Pointer<Void> pvReserved,
  Pointer<Void> pPromptStruct,
  Uint32 dwFlags,
  Pointer<_DataBlob> pDataOut,
);

typedef _CryptProtectDataDart = int Function(
  Pointer<_DataBlob> pDataIn,
  Pointer<Utf16> szDataDescr,
  Pointer<_DataBlob> pOptionalEntropy,
  Pointer<Void> pvReserved,
  Pointer<Void> pPromptStruct,
  int dwFlags,
  Pointer<_DataBlob> pDataOut,
);

typedef _CryptUnprotectDataNative = Int32 Function(
  Pointer<_DataBlob> pDataIn,
  Pointer<Pointer<Utf16>> ppszDataDescr,
  Pointer<_DataBlob> pOptionalEntropy,
  Pointer<Void> pvReserved,
  Pointer<Void> pPromptStruct,
  Uint32 dwFlags,
  Pointer<_DataBlob> pDataOut,
);

typedef _CryptUnprotectDataDart = int Function(
  Pointer<_DataBlob> pDataIn,
  Pointer<Pointer<Utf16>> ppszDataDescr,
  Pointer<_DataBlob> pOptionalEntropy,
  Pointer<Void> pvReserved,
  Pointer<Void> pPromptStruct,
  int dwFlags,
  Pointer<_DataBlob> pDataOut,
);

typedef _LocalFreeNative = Pointer<Void> Function(Pointer<Void> hMem);
typedef _LocalFreeDart = Pointer<Void> Function(Pointer<Void> hMem);

/// Windows DPAPI tabanlı güvenli şifreleme servisi.
/// Bot token ve hassas bilgileri Windows kullanıcısının anahtarıyla şifreler,
/// diskte asla düz metin (plain text) olarak saklanmaz.
class SecureStorageService {
  static const String _dpapiPrefix = 'dpapi:';

  static DynamicLibrary? _crypt32;
  static DynamicLibrary? _kernel32;
  static _CryptProtectDataDart? _cryptProtectData;
  static _CryptUnprotectDataDart? _cryptUnprotectData;
  static _LocalFreeDart? _localFree;
  static bool _initialized = false;

  static void _init() {
    if (_initialized) return;
    _initialized = true;

    if (!Platform.isWindows) return;

    try {
      _crypt32 = DynamicLibrary.open('Crypt32.dll');
      _kernel32 = DynamicLibrary.open('kernel32.dll');

      _cryptProtectData = _crypt32!.lookupFunction<
          _CryptProtectDataNative, _CryptProtectDataDart>('CryptProtectData');
      _cryptUnprotectData = _crypt32!.lookupFunction<
          _CryptUnprotectDataNative, _CryptUnprotectDataDart>('CryptUnprotectData');
      _localFree = _kernel32!.lookupFunction<
          _LocalFreeNative, _LocalFreeDart>('LocalFree');
    } catch (_) {
      // Windows kütüphaneleri yüklenemezse null kalır
    }
  }

  /// Verilen metni Windows DPAPI ile şifreler ve Base64 formatında döndürür.
  static String encrypt(String plainText) {
    if (plainText.isEmpty) return '';

    _init();

    if (_cryptProtectData == null || _localFree == null) {
      return plainText;
    }

    Pointer<Uint8>? inPtr;
    Pointer<_DataBlob>? inBlob;
    Pointer<_DataBlob>? outBlob;

    try {
      final bytes = utf8.encode(plainText);
      inPtr = malloc<Uint8>(bytes.length);
      for (int i = 0; i < bytes.length; i++) {
        inPtr[i] = bytes[i];
      }

      inBlob = malloc<_DataBlob>();
      inBlob.ref.cbData = bytes.length;
      inBlob.ref.pbData = inPtr;

      outBlob = malloc<_DataBlob>();

      // CRYPTPROTECT_UI_FORBIDDEN = 0x1 (kullanıcı arayüzü göstermeden sessiz şifreleme)
      final result = _cryptProtectData!(
        inBlob,
        nullptr,
        nullptr,
        nullptr,
        nullptr,
        0x1,
        outBlob,
      );

      if (result == 0) {
        return plainText;
      }

      final cipherBytes = Uint8List(outBlob.ref.cbData);
      for (int i = 0; i < outBlob.ref.cbData; i++) {
        cipherBytes[i] = outBlob.ref.pbData[i];
      }

      final base64Cipher = base64.encode(cipherBytes);
      return '$_dpapiPrefix$base64Cipher';
    } catch (_) {
      return plainText;
    } finally {
      if (outBlob != null) {
        if (outBlob.ref.pbData != nullptr && _localFree != null) {
          _localFree!(outBlob.ref.pbData.cast<Void>());
        }
        malloc.free(outBlob);
      }
      if (inBlob != null) malloc.free(inBlob);
      if (inPtr != null) malloc.free(inPtr);
    }
  }

  /// Şifrelenmiş DPAPI metnini çözer. Eğer veri şifrelenmemişse düz metin olarak döner.
  static String decrypt(String cipherText) {
    if (cipherText.isEmpty) return '';

    if (!cipherText.startsWith(_dpapiPrefix)) {
      // Zaten düz metin saklanmışsa geriye dönük uyumluluk için aynen döndür
      return cipherText;
    }

    _init();

    if (_cryptUnprotectData == null || _localFree == null) {
      return cipherText;
    }

    final rawBase64 = cipherText.substring(_dpapiPrefix.length);

    Pointer<Uint8>? inPtr;
    Pointer<_DataBlob>? inBlob;
    Pointer<_DataBlob>? outBlob;

    try {
      final cipherBytes = base64.decode(rawBase64);
      inPtr = malloc<Uint8>(cipherBytes.length);
      for (int i = 0; i < cipherBytes.length; i++) {
        inPtr[i] = cipherBytes[i];
      }

      inBlob = malloc<_DataBlob>();
      inBlob.ref.cbData = cipherBytes.length;
      inBlob.ref.pbData = inPtr;

      outBlob = malloc<_DataBlob>();

      final result = _cryptUnprotectData!(
        inBlob,
        nullptr,
        nullptr,
        nullptr,
        nullptr,
        0x1,
        outBlob,
      );

      if (result == 0) {
        return cipherText;
      }

      final plainBytes = Uint8List(outBlob.ref.cbData);
      for (int i = 0; i < outBlob.ref.cbData; i++) {
        plainBytes[i] = outBlob.ref.pbData[i];
      }

      return utf8.decode(plainBytes);
    } catch (_) {
      return cipherText;
    } finally {
      if (outBlob != null) {
        if (outBlob.ref.pbData != nullptr && _localFree != null) {
          _localFree!(outBlob.ref.pbData.cast<Void>());
        }
        malloc.free(outBlob);
      }
      if (inBlob != null) malloc.free(inBlob);
      if (inPtr != null) malloc.free(inPtr);
    }
  }
}
