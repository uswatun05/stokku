import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'storage_service.dart';

enum BeepType {
  success,
  error,
  scan,
  warning,
}

class AudioService {
  // Singleton pattern
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal() {
    _initPrecomputedSounds();
  }

  final AudioPlayer _player = AudioPlayer();
  bool _isMuted = false;

  bool get isMuted => _isMuted;

  // Cached in-memory byte sources (Synthesizer tone PCM WAV)
  late final Uint8List _successBytes;
  late final Uint8List _errorBytes;
  late final Uint8List _scanBytes;
  late final Uint8List _warningBytes;

  // ==========================================
  // 1. INITIALIZATION & SOUND SYNTHESIS
  // ==========================================
  Future<void> init() async {
    _isMuted = await StorageService().isAudioMuted();
    // Konfigurasi audioplayer agar siap memainkan sound effect berulang tanpa delay
    await _player.setReleaseMode(ReleaseMode.stop);
  }

  void _initPrecomputedSounds() {
    // 1. Success tone: 880Hz (A5) -> 1760Hz (A6), 120ms (mirip Web Audio API index.html)
    _successBytes = _generateWav(
      startFreq: 880.0,
      endFreq: 1760.0,
      durationSeconds: 0.12,
      volume: 0.5,
    );

    // 2. Error tone: 220Hz -> 150Hz, 250ms (rendah & tegas)
    _errorBytes = _generateWav(
      startFreq: 220.0,
      endFreq: 150.0,
      durationSeconds: 0.25,
      volume: 0.6,
    );

    // 3. Scan chirp: 1200Hz, 80ms (khas pemindai barcode supermarket)
    _scanBytes = _generateWav(
      startFreq: 1200.0,
      endFreq: 1200.0,
      durationSeconds: 0.08,
      volume: 0.45,
    );

    // 4. Warning / Alert: 440Hz -> 330Hz, 200ms
    _warningBytes = _generateWav(
      startFreq: 440.0,
      endFreq: 330.0,
      durationSeconds: 0.20,
      volume: 0.55,
    );
  }

  // ==========================================
  // 2. PLAYBACK FUNCTIONS
  // ==========================================

  /// Memutar efek suara beep berdasarkan tipe
  Future<void> playBeep(BeepType type) async {
    if (_isMuted) return;

    try {
      Uint8List targetBytes;
      switch (type) {
        case BeepType.success:
          targetBytes = _successBytes;
          break;
        case BeepType.error:
          targetBytes = _errorBytes;
          break;
        case BeepType.scan:
          targetBytes = _scanBytes;
          break;
        case BeepType.warning:
          targetBytes = _warningBytes;
          break;
      }

      await _player.stop();
      await _player.play(BytesSource(targetBytes));
    } catch (e) {
      // Tangani jika platform audio sedang sibuk
    }
  }

  /// Shortcut kemudahan pemanggilan di UI
  Future<void> playSuccess() => playBeep(BeepType.success);
  Future<void> playError() => playBeep(BeepType.error);
  Future<void> playScan() => playBeep(BeepType.scan);
  Future<void> playWarning() => playBeep(BeepType.warning);

  /// Menyalakan / mematikan suara aplikasi
  Future<void> toggleMute() async {
    _isMuted = !_isMuted;
    await StorageService().setAudioMuted(_isMuted);
  }

  Future<void> setMuted(bool muted) async {
    _isMuted = muted;
    await StorageService().setAudioMuted(_isMuted);
  }

  // ==========================================
  // 3. INTERNAL WAV PCM AUDIO GENERATOR (OFFLINE)
  // ==========================================
  /// Menghasilkan format WAV 16-bit PCM Mono 44.1kHz murni di memori tanpa perlu aset file mp3 eksternal
  Uint8List _generateWav({
    required double startFreq,
    required double endFreq,
    required double durationSeconds,
    double volume = 0.5,
  }) {
    const int sampleRate = 44100;
    final int totalSamples = (sampleRate * durationSeconds).round();
    final int byteLength = 44 + (totalSamples * 2);
    final ByteData byteData = ByteData(byteLength);

    // RIFF Header
    byteData.setUint8(0, 0x52); // 'R'
    byteData.setUint8(1, 0x49); // 'I'
    byteData.setUint8(2, 0x46); // 'F'
    byteData.setUint8(3, 0x46); // 'F'
    byteData.setUint32(4, byteLength - 8, Endian.little);
    byteData.setUint8(8, 0x57); // 'W'
    byteData.setUint8(9, 0x41); // 'A'
    byteData.setUint8(10, 0x56); // 'V'
    byteData.setUint8(11, 0x45); // 'E'

    // 'fmt ' Sub-chunk
    byteData.setUint8(12, 0x66); // 'f'
    byteData.setUint8(13, 0x6D); // 'm'
    byteData.setUint8(14, 0x74); // 't'
    byteData.setUint8(15, 0x20); // ' '
    byteData.setUint32(16, 16, Endian.little); // Subchunk size (16 for PCM)
    byteData.setUint16(20, 1, Endian.little); // Audio format (1 = PCM)
    byteData.setUint16(22, 1, Endian.little); // Num channels (1 = mono)
    byteData.setUint32(24, sampleRate, Endian.little); // Sample rate
    byteData.setUint32(28, sampleRate * 2, Endian.little); // Byte rate
    byteData.setUint16(32, 2, Endian.little); // Block align (1 channel * 2 bytes)
    byteData.setUint16(34, 16, Endian.little); // Bits per sample (16 bit)

    // 'data' Sub-chunk
    byteData.setUint8(36, 0x64); // 'd'
    byteData.setUint8(37, 0x61); // 'a'
    byteData.setUint8(38, 0x74); // 't'
    byteData.setUint8(39, 0x61); // 'a'
    byteData.setUint32(40, totalSamples * 2, Endian.little);

    // Sintesis gelombang sinus dengan envelope fade-out halus
    double phase = 0.0;
    int offset = 44;
    for (int i = 0; i < totalSamples; i++) {
      final double t = i / totalSamples;
      final double currentFreq = startFreq + (endFreq - startFreq) * t;
      phase += 2 * pi * currentFreq / sampleRate;

      // Envelope peredam klik / distorsi audio
      final double envelope = (1.0 - t).clamp(0.0, 1.0);
      final double sampleVal = sin(phase) * volume * envelope;
      final int intSample = (sampleVal * 32767.0).clamp(-32768.0, 32767.0).round();

      byteData.setInt16(offset, intSample, Endian.little);
      offset += 2;
    }

    return byteData.buffer.asUint8List();
  }

  void dispose() {
    _player.dispose();
  }
}

