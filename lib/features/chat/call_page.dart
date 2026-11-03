import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../core/constants/app_colors.dart';
import 'call_service.dart';
import '../../core/constants/app_tokens.dart';

/// Layar telepon / video call (masuk maupun keluar).
class CallPage extends StatefulWidget {
  const CallPage({super.key, required this.session});
  final CallSession session;
  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  CallSession get s => widget.session;
  Offset _pip = const Offset(16, 96);
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    s.addListener(_changed);
    if (s.outgoing) {
      s.startOutgoing();
    } else {
      s.startRinging();
    }
  }

  @override
  void dispose() {
    s.removeListener(_changed);
    s.release();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    if (s.phase == CallPhase.ended && !_closing) {
      _closing = true;
      // tampilkan alasan sebentar, lalu tutup
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) Navigator.of(context).maybePop();
      });
    }
  }

  String get _status => switch (s.phase) {
        CallPhase.calling => 'Memanggil…',
        CallPhase.ringing => s.video ? 'Panggilan video masuk' : 'Panggilan suara masuk',
        CallPhase.connecting => 'Menghubungkan…',
        CallPhase.connected => _fmt(s.connectedFor),
        CallPhase.ended => s.endReason ?? 'Panggilan selesai',
      };

  static String _fmt(Duration d) {
    final m = d.inMinutes, sec = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  String get _initials {
    final w = s.peerName.split(',').first.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).take(2);
    return w.map((e) => e[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final showRemoteVideo = s.video && s.hasRemoteVideo && s.phase == CallPhase.connected;
    final showLocalVideo = s.video && s.renderersReady && !s.cameraOff && s.phase != CallPhase.ended;
    final size = MediaQuery.sizeOf(context);
    return PopScope(
      canPop: s.phase == CallPhase.ended,
      child: Scaffold(
        backgroundColor: AppColors.navy,
        body: Stack(children: [
          // latar: video lawan bicara, atau gradasi + inisial
          Positioned.fill(
            child: showRemoteVideo
                ? RTCVideoView(s.remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
                : DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF1B3478), Color(0xFF0B1838)],
                      ),
                    ),
                    child: showLocalVideo && s.phase != CallPhase.connected
                        ? Opacity(opacity: 0.55, child: RTCVideoView(s.localRenderer, mirror: s.frontCamera, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover))
                        : null,
                  ),
          ),
          // nama + status
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(top: showRemoteVideo ? 12 : size.height * 0.1),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (!showRemoteVideo) ...[
                    Container(
                      width: 112,
                      height: 112,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 2),
                      ),
                      child: Text(_initials, style: const TextStyle(color: Colors.white, fontSize: AppType.hero, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(height: 18),
                  ],
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(s.peerName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: AppType.h2, fontWeight: FontWeight.w800, shadows: [Shadow(blurRadius: 8, color: Colors.black45)])),
                  ),
                  const SizedBox(height: 6),
                  Text(_status,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: AppType.lead,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          shadows: const [Shadow(blurRadius: 8, color: Colors.black45)])),
                ]),
              ),
            ),
          ),
          // video sendiri (kecil, bisa digeser)
          if (showLocalVideo && s.phase == CallPhase.connected)
            Positioned(
              right: _pip.dx,
              top: _pip.dy,
              child: GestureDetector(
                onPanUpdate: (d) => setState(() {
                  _pip = Offset(
                    (_pip.dx - d.delta.dx).clamp(8.0, size.width - 128),
                    (_pip.dy + d.delta.dy).clamp(40.0, size.height - 260),
                  );
                }),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                  child: SizedBox(width: 112, height: 160, child: RTCVideoView(s.localRenderer, mirror: s.frontCamera, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)),
                ),
              ),
            ),
          // tombol
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(padding: const EdgeInsets.only(bottom: 28), child: _controls()),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _controls() {
    if (s.phase == CallPhase.ended) return const SizedBox(height: 72);
    if (s.phase == CallPhase.ringing) {
      return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _RoundBtn(icon: CupertinoIcons.phone_down_fill, label: 'Tolak', color: AppColors.red, onTap: s.decline, big: true),
        _RoundBtn(icon: s.video ? CupertinoIcons.videocam_fill : CupertinoIcons.phone_fill, label: 'Jawab', color: AppColors.emerald, onTap: s.accept, big: true),
      ]);
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _RoundBtn(icon: s.muted ? CupertinoIcons.mic_slash_fill : CupertinoIcons.mic_fill, label: s.muted ? 'Bisu' : 'Mikrofon', on: s.muted, onTap: s.toggleMute),
        _RoundBtn(icon: s.speaker ? CupertinoIcons.speaker_2_fill : CupertinoIcons.ear, label: 'Speaker', on: s.speaker, onTap: s.toggleSpeaker),
        if (s.video) _RoundBtn(icon: s.cameraOff ? CupertinoIcons.video_camera : CupertinoIcons.videocam_fill, label: 'Kamera', on: s.cameraOff, onTap: s.toggleCamera),
        if (s.video) _RoundBtn(icon: CupertinoIcons.camera_rotate, label: 'Balik', onTap: s.switchCamera),
      ]),
      const SizedBox(height: 22),
      _RoundBtn(icon: CupertinoIcons.phone_down_fill, label: 'Akhiri', color: AppColors.red, onTap: () => s.hangup(), big: true),
    ]);
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.icon, required this.label, required this.onTap, this.color, this.on = false, this.big = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool on, big;

  @override
  Widget build(BuildContext context) {
    final d = big ? 68.0 : 56.0;
    final bg = color ?? (on ? Colors.white : Colors.white.withValues(alpha: 0.16));
    final fg = color != null ? Colors.white : (on ? AppColors.navy : Colors.white);
    return Semantics(
      button: true,
      label: label,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Material(
          color: bg,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(width: d, height: d, child: Icon(icon, color: fg, size: big ? 32 : 26)),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: AppType.caption)),
      ]),
    );
  }
}
