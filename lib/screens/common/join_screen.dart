// ignore_for_file: non_constant_identifier_names, dead_code

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:agent_starter_flutter/widgets/holographic_orb.dart';
import 'package:videosdk/videosdk.dart';
import 'package:agent_starter_flutter/widgets/talk_button.dart';
import 'package:agent_starter_flutter/utils/api.dart';
import 'package:agent_starter_flutter/utils/route.dart';
import 'package:agent_starter_flutter/widgets/agent_state_pill.dart';

import '../../utils/toast.dart';
import '../one-to-one/one_to_one_meeting_screen.dart';

// ─────────────────────────────────────────────
//  Join Screen
// ─────────────────────────────────────────────
class JoinScreen extends StatefulWidget {
  const JoinScreen({Key? key}) : super(key: key);

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> with WidgetsBindingObserver {
  String _token = '';

  // ── connection state ──────────────────────
  bool _isConnecting = false;

  // ── AV state ──────────────────────────────
  bool isMicOn =
      !kIsWeb && (Platform.isMacOS || Platform.isWindows) ? true : false;
  bool isCameraOn = false;

  CustomTrack? cameraTrack;
  CustomTrack? microphoneTrack;
  RTCVideoRenderer? cameraRenderer;

  bool? isJoinMeetingSelected;
  bool? isCreateMeetingSelected;

  bool? isCameraPermissionAllowed = false;
  bool? isMicrophonePermissionAllowed =
      !kIsWeb && (Platform.isMacOS || Platform.isWindows) ? true : false;

  VideoDeviceInfo? selectedVideoDevice;
  AudioDeviceInfo? selectedAudioOutputDevice;
  AudioDeviceInfo? selectedAudioInputDevice;
  List<VideoDeviceInfo>? videoDevices;
  List<AudioDeviceInfo>? audioDevices;
  List<AudioDeviceInfo> audioInputDevices = [];
  List<AudioDeviceInfo> audioOutputDevices = [];

  late Function handler;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final token = await fetchToken(context);
      setState(() => _token = token);
    });
    checkandReqPermissions();
    subscribe();
  }

  // ── device helpers ────────────────────────
  void updateselectedAudioOutputDevice(AudioDeviceInfo? device) {
    if (device?.deviceId != selectedAudioOutputDevice?.deviceId) {
      setState(() => selectedAudioOutputDevice = device);
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        disposeMicTrack();
        initMic();
      }
    }
  }

  void updateselectedAudioInputDevice(AudioDeviceInfo? device) {
    if (device?.deviceId != selectedAudioInputDevice?.deviceId) {
      setState(() => selectedAudioInputDevice = device);
      disposeMicTrack();
      initMic();
    }
  }

  void updateSelectedVideoDevice(VideoDeviceInfo? device) {
    if (device?.deviceId != selectedVideoDevice?.deviceId) {
      disposeCameraPreview();
      setState(() => selectedVideoDevice = device);
      initCameraPreview();
    }
  }

  Future<void> checkBluetoothPermissions() async {
    try {
      final bt = await VideoSDK.checkBluetoothPermission();
      if (!bt) await VideoSDK.requestBluetoothPermission();
    } catch (_) {}
  }

  void getDevices() async {
    if (isCameraPermissionAllowed == true) {
      videoDevices = await VideoSDK.getVideoDevices();
      setState(() => selectedVideoDevice = videoDevices?.first);
      initCameraPreview();
    }
    if (isMicrophonePermissionAllowed == true) {
      audioDevices = await VideoSDK.getAudioDevices();
      if (!kIsWeb && !Platform.isMacOS && !Platform.isWindows) {
        setState(() => selectedAudioOutputDevice = audioDevices?.first);
      } else {
        audioInputDevices = [];
        audioOutputDevices = [];
        for (final d in audioDevices!) {
          if (d.kind == 'audioinput') {
            audioInputDevices.add(d);
          } else {
            audioOutputDevices.add(d);
          }
        }
        setState(() {
          selectedAudioOutputDevice = audioOutputDevices.first;
          selectedAudioInputDevice = audioInputDevices.first;
        });
        initMic();
      }
    }
  }

  void checkandReqPermissions([Permissions? perm]) async {
    perm ??= Permissions.audio; // audio only — camera is disabled
    try {
      if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
        final permissions = await VideoSDK.checkPermissions();
        if (perm == Permissions.audio || perm == Permissions.audio_video) {
          if (permissions['audio'] != true) {
            final req = await VideoSDK.requestPermissions(Permissions.audio);
            setState(() {
              isMicrophonePermissionAllowed = req['audio'];
              isMicOn = req['audio']!;
            });
          } else {
            setState(() {
              isMicrophonePermissionAllowed = true;
              isMicOn = true;
            });
          }
        }
        // Camera permission intentionally skipped — camera is always off
        if (!kIsWeb && Platform.isAndroid) await checkBluetoothPermissions();
      }
      getDevices();
    } catch (_) {}
  }

  void checkPermissions() async {
    if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
      final permissions = await VideoSDK.checkPermissions();
      setState(() {
        isMicrophonePermissionAllowed = permissions['audio'];
        isMicOn = permissions['audio']!;
        // isCameraOn intentionally left as false — camera is always off
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) checkPermissions();
  }

  @override
  setState(fn) {
    if (mounted) super.setState(fn);
  }

  Future<void> _onTalkToAgent() async {
    if (_token.isEmpty || _isConnecting) return;

    try {
      // 1. Check if a hardcoded room ID is set in .env
      final String? envRoomId = dotenv.env['MEETING_ID'];

      String roomId;

      if (envRoomId != null && envRoomId.isNotEmpty) {
        // 2a. Validate the existing room ID before using it
        final bool isValid = await validateMeeting(_token, envRoomId);
        if (!isValid) {
          throw Exception("Meeting ID from .env is invalid.");
        }
        roomId = envRoomId;
      } else {
        // 2b. No room ID in env — create a fresh one
        roomId = await createMeeting(_token);
      }

      _navigateToMeeting(roomId);
    } catch (e) {
      if (mounted) {
        setState(() => _isConnecting = false);
        showSnackBarMessage(
          message: "Failed to connect: ${e.toString()}",
          context: context,
        );
      }
    }
  }

  void _navigateToMeeting(String roomId) {
    if (!mounted) return;
    setState(() => cameraRenderer = null);
    unsubscribe();
    Navigator.push(
      context,
      fadeRoute(
        OneToOneMeetingScreen(
          token: _token,
          meetingId: roomId,
          displayName: 'Guest',
          micEnabled: isMicOn,
          camEnabled: false,
          selectedAudioOutputDevice: selectedAudioOutputDevice,
          selectedAudioInputDevice: selectedAudioInputDevice,
          cameraTrack: cameraTrack,
          micTrack: microphoneTrack,
          isVideoPermissionAsked: false,
        ),
      ),
    ).then((_) {
      if (mounted) setState(() => _isConnecting = false);
    });
  }

  // ── BUILD ─────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) _onWillPopScope();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _buildMainBody(),
      ),
    );
  }

  Widget _buildMainBody() {
    final size = MediaQuery.of(context).size;
    final topSafeArea = MediaQuery.of(context).padding.top;
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;

    const headerHeight = 62.0;
    const gapBelowHeader = 18.0;
    const horizontalPadding = 16.0;
    const bottomBarHeight = 80.0; // height of _TalkButton + its padding

    final contentTop = topSafeArea + 8 + headerHeight + gapBelowHeader;
    final bottomReserved = bottomBarHeight + bottomSafeArea;
    final orbAreaHeight = size.height - contentTop - bottomReserved;

    return Stack(
      children: [
        // ── Radial background ────────────────────────────────────────
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.1,
                colors: [Color(0xFF000000), Color(0xFF000000)],
              ),
            ),
          ),
        ),

        // ── Top vignette ─────────────────────────────────────────────
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 200,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.4),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // ── Bottom vignette ──────────────────────────────────────────
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 280,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(0.85),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // ── Header ───────────────────────────────────────────────────
        Positioned(
          top: topSafeArea + 8,
          left: horizontalPadding,
          right: horizontalPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Powered by VideoSDK',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.38),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.2,
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _isConnecting
                    ? const Padding(
                        key: ValueKey('pill'),
                        padding: EdgeInsets.only(top: 6),
                        child: ConnectingPill(),
                      )
                    : const SizedBox(key: ValueKey('empty'), height: 38),
                // ↑ SizedBox height = top padding(6) + pill height(32)
                //   so header total stays 62px whether pill shows or not
              ),
            ],
          ),
        ),

        // ── Orb — same region as bigFeed in meeting screen ───────────
        Positioned(
          top: contentTop,
          left: horizontalPadding,
          right: horizontalPadding,
          height: orbAreaHeight,
          child: Center(
            child: HolographicOrb(isConnecting: _isConnecting),
          ),
        ),

        // ── Talk button — pinned at bottom, same as bottom bar ───────
        Positioned(
          bottom: bottomSafeArea + 16,
          left: horizontalPadding,
          right: horizontalPadding,
          child: AnimatedOpacity(
            opacity: _isConnecting ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 250),
            child: IgnorePointer(
              ignoring: _isConnecting,
              child: TalkButton(onTap: _onTalkToAgent),
            ),
          ),
        ),
      ],
    );
  }

  // ── original helpers ──────────────────────
  Future<bool> _onWillPopScope() async {
    if (isJoinMeetingSelected != null && isCreateMeetingSelected != null) {
      setState(() {
        isJoinMeetingSelected = null;
        isCreateMeetingSelected = null;
      });
      return false;
    }
    return true;
  }

  void initCameraPreview() async {
    if (isCameraPermissionAllowed == true) {
      final track = await VideoSDK.createCameraVideoTrack(
          cameraId: selectedVideoDevice?.deviceId);
      final render = RTCVideoRenderer();
      await render.initialize();
      render.setSrcObject(
        stream: track?.mediaStream,
        trackId: track?.mediaStream.getVideoTracks().first.id,
      );
      setState(() {
        cameraTrack = track;
        cameraRenderer = render;
        isCameraOn = true;
      });
    }
  }

  void initMic() async {
    if (isMicrophonePermissionAllowed == true) {
      final track = await VideoSDK.createMicrophoneAudioTrack(
        microphoneId: kIsWeb || Platform.isMacOS || Platform.isWindows
            ? selectedAudioInputDevice?.deviceId
            : selectedAudioOutputDevice?.deviceId,
      );
      setState(() => microphoneTrack = track);
    }
  }

  void disposeCameraPreview() {
    cameraTrack?.dispose();
    setState(() {
      cameraRenderer = null;
      cameraTrack = null;
    });
  }

  void disposeMicTrack() {
    microphoneTrack?.dispose();
    setState(() => microphoneTrack = null);
  }

  void subscribe() {
    handler = (_) => getDevices();
    VideoSDK.on(Events.deviceChanged, handler);
  }

  void unsubscribe() {
    VideoSDK.off(Events.deviceChanged, handler);
  }

  @override
  void dispose() {
    unsubscribe();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }
}
