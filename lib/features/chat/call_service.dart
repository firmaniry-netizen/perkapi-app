import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/env.dart';
import '../../core/services/push_service.dart';
import '../../core/services/supabase_service.dart';
import 'call_page.dart';
import 'incoming_call_ui.dart';

/// Telepon & video call 1-lawan-1 (WebRTC, peer-to-peer).
///
/// Sinyal (offer/answer/ICE/akhir) lewat tabel `chat_call_signals` (SQL 41) + Supabase Realtime:
/// tiap baris hanya terbaca oleh pengirim dan penerimanya (RLS). Suara/video mengalir langsung antar-HP;
/// server STUN membantu menembus NAT, dan server TURN Cloudflare (kredensial sementara dari fungsi
/// Supabase `turn-credentials`) dipakai otomatis bila jaringan memblokir koneksi langsung (mis. data seluler).
class CallService with WidgetsBindingObserver {
  CallService._();
  static final instance = CallService._();

  final _db = SupabaseService.client;
  RealtimeChannel? _ch;
  String? _me;
  BuildContext? _ctx;
  CallSession? active;
  final _handled = <String>{}; // call_id yang sudah diproses (hindari dering ganda)
  (String, bool)? _pendingAction; // Jawab/Tolak dari layar dering sebelum CallService siap
  StreamSubscription<RemoteMessage>? _fcmSub;

  /// Dipanggil AppShell setelah masuk. [ctx] dipakai untuk membuka layar panggilan.
  void start(String? memberId, BuildContext ctx) {
    _ctx = ctx;
    if (memberId == null || memberId == _me) return;
    stop();
    _me = memberId;
    WidgetsBinding.instance.addObserver(this);
    _ch = _db
        .channel('calls-$memberId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_call_signals',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'to_member', value: memberId),
          callback: (p) => _onSignal(Map<String, dynamic>.from(p.newRecord)),
        )
        .subscribe();
    // layar dering bawaan Android (aplikasi tertutup/di latar): tombol Jawab/Tolak
    IncomingCallUi.listen((id, accept) => openById(id, accept: accept, decline: !accept));
    IncomingCallUi.requestPermission();
    // push panggilan saat aplikasi terbuka: cek langsung (cadangan bila Realtime terputus)
    if (PushService.instance.available) {
      _fcmSub ??= FirebaseMessaging.onMessage.listen((m) {
        if (m.data['type'] == 'call') _checkPending();
      });
    }
    final pend = _pendingAction;
    _pendingAction = null;
    if (pend != null) {
      openById(pend.$1, accept: pend.$2, decline: !pend.$2);
    } else {
      IncomingCallUi.acceptedOnLaunch().then((id) {
        if (id != null) openById(id, accept: true);
      });
    }
    _checkPending();
  }

  void stop() {
    WidgetsBinding.instance.removeObserver(this);
    _fcmSub?.cancel();
    _fcmSub = null;
    final ch = _ch;
    _ch = null;
    _me = null;
    if (ch != null) _db.removeChannel(ch);
  }

  String? get me => _me;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkPending();
  }

  /// Panggilan yang masuk saat aplikasi tertutup/di latar: cari offer < 40 detik yang belum diakhiri.
  Future<void> _checkPending() async {
    final me = _me;
    if (me == null || active != null) return;
    try {
      final since = DateTime.now().toUtc().subtract(const Duration(seconds: 45)).toIso8601String();
      final rows = List<Map<String, dynamic>>.from(await _db
          .from('chat_call_signals')
          .select()
          .eq('to_member', me)
          .gte('created_at', since)
          .order('created_at', ascending: true));
      final ended = {for (final r in rows) if (r['type'] == 'end') '${r['call_id']}'};
      final offers = rows.where((r) => r['type'] == 'offer' && !ended.contains('${r['call_id']}')).toList();
      if (offers.isNotEmpty) _onSignal(offers.last);
    } catch (_) {}
  }

  /// Tombol Jawab/Tolak pada layar dering bawaan (atau aplikasi dibuka lewat Jawab).
  Future<void> openById(String callId, {bool accept = false, bool decline = false}) async {
    final me = _me;
    if (me == null) {
      _pendingAction = (callId, accept);
      return;
    }
    final cur = active;
    if (cur != null && cur.callId == callId) {
      if (accept) {
        cur.accept();
      } else if (decline) {
        cur.decline();
      }
      return;
    }
    try {
      final rows = List<Map<String, dynamic>>.from(await _db
          .from('chat_call_signals')
          .select()
          .eq('call_id', callId)
          .eq('to_member', me)
          .order('created_at', ascending: true));
      final offers = rows.where((r) => r['type'] == 'offer').toList();
      if (offers.isEmpty || rows.any((r) => r['type'] == 'end')) {
        IncomingCallUi.end(callId);
        return;
      }
      final s = _fromOffer(offers.last);
      _handled.add(callId);
      if (decline) {
        await send(s, 'decline');
        IncomingCallUi.end(callId);
        return;
      }
      if (cur != null) {
        await send(s, 'busy');
        return;
      }
      s.autoAccept = accept;
      await _resolveName(s);
      _present(s);
    } catch (_) {}
  }

  CallSession _fromOffer(Map<String, dynamic> r) => CallSession(
        service: this,
        callId: '${r['call_id']}',
        threadId: '${r['thread_id']}',
        peerId: '${r['from_member']}',
        peerName: 'Anggota',
        video: r['video'] == true,
        outgoing: false,
        remoteOffer: r['payload'] is Map ? Map<String, dynamic>.from(r['payload'] as Map) : null,
      );

  Future<void> send(CallSession s, String type, [Map<String, dynamic>? payload]) async {
    final me = _me;
    if (me == null) return;
    try {
      await _db.from('chat_call_signals').insert({
        'call_id': s.callId,
        'thread_id': s.threadId,
        'from_member': me,
        'to_member': s.peerId,
        'type': type,
        'video': s.video,
        if (payload != null) 'payload': payload,
      });
    } catch (_) {}
  }

  void _onSignal(Map<String, dynamic> r) {
    final type = '${r['type']}', callId = '${r['call_id']}';
    final s = active;
    if (type == 'offer') {
      if (_handled.contains(callId)) return;
      _handled.add(callId);
      final incoming = _fromOffer(r);
      if (s != null) {
        // sedang dalam panggilan lain: tolak otomatis sebagai "sibuk"
        send(incoming, 'busy');
        return;
      }
      _resolveName(incoming).then((_) => _present(incoming));
      return;
    }
    if (s == null || s.callId != callId) return;
    s.onSignal(type, r['payload'] is Map ? Map<String, dynamic>.from(r['payload'] as Map) : null);
  }

  Future<void> _resolveName(CallSession s) async {
    try {
      final rows = List<Map<String, dynamic>>.from(await _db.rpc('chat_thread_members', params: {'p_thread': s.threadId}) as List);
      final m = rows.firstWhere((e) => '${e['member_id']}' == s.peerId, orElse: () => const {});
      if (m['name'] != null) s.peerName = '${m['name']}';
    } catch (_) {}
  }

  void _present(CallSession s) {
    final ctx = _ctx;
    if (ctx == null || !ctx.mounted) return;
    active = s;
    Navigator.of(ctx, rootNavigator: true).push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => CallPage(session: s)));
  }

  /// Mulai panggilan keluar dari halaman chat (hanya percakapan pribadi).
  Future<void> call(BuildContext context, {required String threadId, required String peerId, required String peerName, required bool video}) async {
    if (active != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Masih ada panggilan yang berlangsung.')));
      return;
    }
    if (_me == null) return;
    final s = CallSession(
      service: this,
      callId: _uuid(),
      threadId: threadId,
      peerId: peerId,
      peerName: peerName,
      video: video,
      outgoing: true,
    );
    _handled.add(s.callId);
    active = s;
    await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => CallPage(session: s)));
  }

  void finished(CallSession s) {
    if (identical(active, s)) active = null;
  }

  /// Ringkasan panggilan sebagai pesan di chat (ditulis oleh penelepon saja agar tidak ganda).
  Future<void> logCall(CallSession s, {required bool answered}) async {
    final me = _me;
    if (me == null || !s.outgoing) return;
    final kind = s.video ? 'Panggilan video' : 'Panggilan suara';
    final body = answered && s.connectedFor > Duration.zero
        ? '$kind · ${_dur(s.connectedFor)}'
        : '$kind tidak terjawab';
    try {
      await _db.from('chat_messages').insert({'thread_id': s.threadId, 'sender_id': me, 'body': body, 'kind': 'call'});
    } catch (_) {}
  }

  static String _dur(Duration d) {
    final h = d.inHours, m = d.inMinutes % 60, sec = d.inSeconds % 60;
    final mm = m.toString().padLeft(2, '0'), ss = sec.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$m:$ss';
  }

  static String _uuid() {
    final rng = math.Random.secure();
    final rnd = List<int>.generate(16, (_) => rng.nextInt(256));
    rnd[6] = (rnd[6] & 0x0f) | 0x40;
    rnd[8] = (rnd[8] & 0x3f) | 0x80;
    final h = rnd.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }
}

enum CallPhase { calling, ringing, connecting, connected, ended }

/// Satu panggilan: koneksi WebRTC, media lokal/jarak jauh, dan statusnya.
class CallSession extends ChangeNotifier {
  CallSession({
    required this.service,
    required this.callId,
    required this.threadId,
    required this.peerId,
    required this.peerName,
    required this.video,
    required this.outgoing,
    this.remoteOffer,
  }) : phase = outgoing ? CallPhase.calling : CallPhase.ringing;

  final CallService service;
  final String callId, threadId, peerId;
  String peerName;
  final bool video, outgoing;
  final Map<String, dynamic>? remoteOffer;

  /// Sudah dijawab lewat layar dering bawaan: langsung sambungkan tanpa berdering lagi.
  bool autoAccept = false;
  AudioPlayer? _tone;

  CallPhase phase;
  String? endReason;
  bool muted = false, speaker = false, cameraOff = false, frontCamera = true;
  final localRenderer = RTCVideoRenderer();
  final remoteRenderer = RTCVideoRenderer();
  bool renderersReady = false, hasRemoteVideo = false;

  RTCPeerConnection? _pc;
  MediaStream? _local;
  final _pendingIce = <RTCIceCandidate>[];
  bool _remoteSet = false, _closed = false, _answered = false;
  DateTime? _connectedAt;
  Timer? _ringTimeout, _vibe, _ticker, _dropTimer;

  Duration get connectedFor => _connectedAt == null ? Duration.zero : DateTime.now().difference(_connectedAt!);

  // ---- server ICE: STUN publik + TURN Cloudflare (kredensial sementara dari fungsi Supabase `turn-credentials`) ----
  static List<Map<String, dynamic>>? _turnCache;
  static DateTime? _turnUntil;

  /// Ambil kredensial TURN dari server (kunci Cloudflare hanya ada di server, tidak di aplikasi).
  /// Disimpan sementara 12 jam; bila gagal, panggilan tetap jalan dengan STUN saja.
  static Future<List<Map<String, dynamic>>> _turnServers() async {
    if (_turnCache != null && _turnUntil != null && DateTime.now().isBefore(_turnUntil!)) return _turnCache!;
    try {
      final r = await SupabaseService.client.functions.invoke('turn-credentials').timeout(const Duration(seconds: 5));
      final data = r.data;
      final raw = data is Map ? data['iceServers'] : null;
      final list = <Map<String, dynamic>>[];
      for (final e in (raw is List ? raw : [raw])) {
        if (e is Map && e['urls'] != null) list.add(Map<String, dynamic>.from(e));
      }
      if (list.isNotEmpty) {
        _turnCache = list;
        _turnUntil = DateTime.now().add(const Duration(hours: 12));
        return list;
      }
    } catch (_) {}
    return const [];
  }

  static Future<Map<String, dynamic>> _config() async => {
        'iceServers': [
          {'urls': ['stun:stun.cloudflare.com:3478', 'stun:stun.l.google.com:19302']},
          ...await _turnServers(),
          if (Env.turnUrl.isNotEmpty) {'urls': Env.turnUrl.split(','), 'username': Env.turnUser, 'credential': Env.turnPass},
        ],
        'sdpSemantics': 'unified-plan',
      };

  Future<void> _initRenderers() async {
    if (renderersReady) return;
    await localRenderer.initialize();
    await remoteRenderer.initialize();
    renderersReady = true;
  }

  Future<bool> _openMedia() async {
    try {
      _local = await navigator.mediaDevices.getUserMedia({
        'audio': {'echoCancellation': true, 'noiseSuppression': true, 'autoGainControl': true},
        'video': video ? {'facingMode': 'user', 'width': 640, 'height': 480, 'frameRate': 24} : false,
      });
      localRenderer.srcObject = _local;
      speaker = video; // video call: pengeras suara; telepon: earpiece
      await Helper.setSpeakerphoneOn(speaker);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _createPc() async {
    final pc = await createPeerConnection(await _config());
    _pc = pc;
    for (final t in _local?.getTracks() ?? const <MediaStreamTrack>[]) {
      await pc.addTrack(t, _local!);
    }
    pc.onIceCandidate = (c) {
      if (c.candidate == null) return;
      service.send(this, 'ice', {'candidate': c.candidate, 'sdpMid': c.sdpMid, 'sdpMLineIndex': c.sdpMLineIndex});
    };
    pc.onTrack = (e) {
      if (e.streams.isEmpty) return;
      remoteRenderer.srcObject = e.streams.first;
      if (e.track.kind == 'video') hasRemoteVideo = true;
      notifyListeners();
    };
    pc.onConnectionState = (st) {
      if (st == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _dropTimer?.cancel();
        if (_connectedAt == null) {
          _connectedAt = DateTime.now();
          _ticker = Timer.periodic(const Duration(seconds: 1), (_) => notifyListeners());
        }
        phase = CallPhase.connected;
        notifyListeners();
      } else if (st == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        // jaringan sempat putus: beri 8 detik untuk tersambung lagi
        _dropTimer ??= Timer(const Duration(seconds: 8), () => hangup(reason: 'Koneksi terputus'));
      } else if (st == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        hangup(reason: _connectedAt == null ? 'Gagal tersambung (jaringan)' : 'Koneksi terputus');
      }
    };
  }

  /// Penelepon: buka media, buat offer, kirim; berhenti otomatis bila 45 detik tidak dijawab.
  Future<void> startOutgoing() async {
    await _initRenderers();
    if (!await _openMedia()) {
      _end('Izin mikrofon${video ? '/kamera' : ''} ditolak', notifyPeer: false);
      return;
    }
    notifyListeners();
    await _createPc();
    final offer = await _pc!.createOffer({'offerToReceiveAudio': true, 'offerToReceiveVideo': video});
    await _pc!.setLocalDescription(offer);
    await service.send(this, 'offer', {'sdp': offer.sdp, 'type': offer.type});
    // nada sambung "tuut… tuut…" lewat speaker telinga (Android & iPhone)
    if (!kIsWeb && !_answered && !_closed) _playTone('sounds/ringback.mp3', earpiece: true);
    _ringTimeout = Timer(const Duration(seconds: 45), () {
      if (!_answered) hangup(reason: 'Tidak dijawab');
    });
  }

  /// Penerima: mulai bergetar sampai dijawab/ditolak.
  void startRinging() {
    if (autoAccept) {
      accept();
      return;
    }
    // dering tetap berbunyi walau sakelar senyap iPhone aktif (seperti panggilan biasa)
    _playTone('sounds/ring.mp3', loud: true);
    HapticFeedback.vibrate();
    _vibe = Timer.periodic(const Duration(milliseconds: 1200), (_) => HapticFeedback.vibrate());
    _ringTimeout = Timer(const Duration(seconds: 45), () {
      if (!_answered) _end('Panggilan tak terjawab', notifyPeer: false);
    });
  }

  Future<void> accept() async {
    final offer = remoteOffer;
    if (offer == null || _answered) return;
    _answered = true;
    _stopRing();
    IncomingCallUi.end(callId);
    phase = CallPhase.connecting;
    notifyListeners();
    await _initRenderers();
    if (!await _openMedia()) {
      await decline();
      return;
    }
    await _createPc();
    await _pc!.setRemoteDescription(RTCSessionDescription('${offer['sdp']}', '${offer['type']}'));
    _remoteSet = true;
    await _drainIce();
    final answer = await _pc!.createAnswer({'offerToReceiveAudio': true, 'offerToReceiveVideo': video});
    await _pc!.setLocalDescription(answer);
    await service.send(this, 'answer', {'sdp': answer.sdp, 'type': answer.type});
  }

  Future<void> decline() async {
    await service.send(this, 'decline');
    _end('Ditolak', notifyPeer: false);
  }

  Future<void> onSignal(String type, Map<String, dynamic>? p) async {
    if (_closed) return;
    switch (type) {
      case 'answer':
        if (p == null || _pc == null) return;
        _answered = true;
        _ringTimeout?.cancel();
        _stopRing();
        phase = CallPhase.connecting;
        notifyListeners();
        await _pc!.setRemoteDescription(RTCSessionDescription('${p['sdp']}', '${p['type']}'));
        _remoteSet = true;
        await _drainIce();
      case 'ice':
        if (p == null) return;
        final c = RTCIceCandidate('${p['candidate']}', p['sdpMid'] as String?, (p['sdpMLineIndex'] as num?)?.toInt());
        if (_remoteSet && _pc != null) {
          try {
            await _pc!.addCandidate(c);
          } catch (_) {}
        } else {
          _pendingIce.add(c);
        }
      case 'decline':
        _end('Panggilan ditolak', notifyPeer: false);
      case 'busy':
        _end('Sedang dalam panggilan lain', notifyPeer: false);
      case 'end':
        _end(_connectedAt == null && !outgoing ? 'Panggilan tak terjawab' : 'Panggilan selesai', notifyPeer: false);
    }
  }

  Future<void> _drainIce() async {
    final pc = _pc;
    if (pc == null) return;
    for (final c in List.of(_pendingIce)) {
      try {
        await pc.addCandidate(c);
      } catch (_) {}
    }
    _pendingIce.clear();
  }

  Future<void> hangup({String reason = 'Panggilan selesai'}) async => _end(reason, notifyPeer: true);

  void toggleMute() {
    muted = !muted;
    for (final t in _local?.getAudioTracks() ?? const <MediaStreamTrack>[]) {
      t.enabled = !muted;
    }
    notifyListeners();
  }

  Future<void> toggleSpeaker() async {
    speaker = !speaker;
    await Helper.setSpeakerphoneOn(speaker);
    notifyListeners();
  }

  void toggleCamera() {
    cameraOff = !cameraOff;
    for (final t in _local?.getVideoTracks() ?? const <MediaStreamTrack>[]) {
      t.enabled = !cameraOff;
    }
    notifyListeners();
  }

  Future<void> switchCamera() async {
    final tracks = _local?.getVideoTracks() ?? const <MediaStreamTrack>[];
    if (tracks.isEmpty) return;
    await Helper.switchCamera(tracks.first);
    frontCamera = !frontCamera;
    notifyListeners();
  }

  /// Nada dering/sambung berulang. [loud]: dering masuk lewat speaker, abaikan sakelar senyap.
  /// [earpiece]: nada sambung pelan lewat speaker telinga (aman dipakai bersama mikrofon WebRTC).
  Future<void> _playTone(String asset, {bool loud = false, bool earpiece = false}) async {
    try {
      final p = _tone ??= AudioPlayer();
      await p.setAudioContext(AudioContextConfig(
        route: earpiece ? AudioContextConfigRoute.earpiece : AudioContextConfigRoute.system,
        respectSilence: !loud && !earpiece,
      ).build());
      await p.setReleaseMode(ReleaseMode.loop);
      await p.play(AssetSource(asset), volume: 0.9);
      if (_answered || _closed) await _stopTone();
    } catch (_) {}
  }

  Future<void> _stopTone() async {
    final p = _tone;
    _tone = null;
    if (p == null) return;
    try {
      await p.stop();
      await p.dispose();
    } catch (_) {}
  }

  void _stopRing() {
    _vibe?.cancel();
    _vibe = null;
    _stopTone();
  }

  Future<void> _end(String reason, {required bool notifyPeer}) async {
    if (_closed) return;
    _closed = true;
    _stopRing();
    _ringTimeout?.cancel();
    _ticker?.cancel();
    _dropTimer?.cancel();
    endReason = reason;
    IncomingCallUi.end(callId);
    phase = CallPhase.ended;
    notifyListeners();
    if (notifyPeer) await service.send(this, 'end');
    await service.logCall(this, answered: _connectedAt != null);
    try {
      for (final t in _local?.getTracks() ?? const <MediaStreamTrack>[]) {
        await t.stop();
      }
      await _local?.dispose();
      await _pc?.close();
    } catch (_) {}
    _local = null;
    _pc = null;
    service.finished(this);
  }

  /// Dipanggil saat layar panggilan ditutup.
  Future<void> release() async {
    if (!_closed) await hangup();
    if (renderersReady) {
      localRenderer.srcObject = null;
      remoteRenderer.srcObject = null;
      await localRenderer.dispose();
      await remoteRenderer.dispose();
      renderersReady = false;
    }
  }
}
