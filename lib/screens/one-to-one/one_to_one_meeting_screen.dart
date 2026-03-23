// ignore_for_file: deprecated_member_use, use_build_context_synchronously, depend_on_referenced_packages

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:videosdk/videosdk.dart';
import 'package:agent_starter_flutter/widgets/bar_button.dart';
import 'package:agent_starter_flutter/widgets/call_timer.dart';
import 'package:agent_starter_flutter/widgets/device_picker_menu.dart';
import 'package:agent_starter_flutter/widgets/joining/participant_limit_reached.dart';
import 'package:agent_starter_flutter/widgets/joining/waiting_to_join.dart';
import 'package:agent_starter_flutter/widgets/meeting_orb.dart';
import 'package:agent_starter_flutter/widgets/permission_denied_dialog.dart';
import 'package:agent_starter_flutter/widgets/top_header.dart';
import 'package:agent_starter_flutter/widgets/transcript_view.dart';
import 'package:videosdk_webrtc/flutter_webrtc.dart';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../../utils/toast.dart';
import '../../widgets/screen_share/screen_select_dialog.dart'
    show ScreenSelectDialog;
import '../common/join_screen.dart';
import 'package:agent_starter_flutter/widgets/agent_state_pill.dart';

List<VideoDeviceInfo>? cameras = [];
List<AudioDeviceInfo>? mics = [];
bool isFrontCam = true;

// ─────────────────────────────────────────────
//  Speaker Indicator — waveform (active) or flat waveform (idle)
// ─────────────────────────────────────────────

// ─────────────────────────────────────────────
//  One-to-One Meeting Screen
// ─────────────────────────────────────────────
// ignore: must_be_immutable
class OneToOneMeetingScreen extends StatefulWidget {
  final String meetingId, token, displayName;
  final bool micEnabled, camEnabled, chatEnabled;
  final AudioDeviceInfo? selectedAudioOutputDevice, selectedAudioInputDevice;
  final CustomTrack? cameraTrack;
  final CustomTrack? micTrack;

  bool isVideoPermissionAsked = false;

  OneToOneMeetingScreen({
    Key? key,
    required this.meetingId,
    required this.token,
    required this.displayName,
    required this.isVideoPermissionAsked,
    this.micEnabled = true,
    this.camEnabled = true,
    this.chatEnabled = true,
    this.selectedAudioOutputDevice,
    this.selectedAudioInputDevice,
    this.cameraTrack,
    this.micTrack,
  }) : super(key: key);

  @override
  OneToOneMeetingScreenState createState() => OneToOneMeetingScreenState();
}

class OneToOneMeetingScreenState extends State<OneToOneMeetingScreen> {
  bool isRecordingOn = false;
  bool showChatSnackbar = true;
  String recordingState = "RECORDING_STOPPED";
  bool _isDispatchingAgent = false;
  late Room meeting;
  bool _joined = false;
  bool _moreThan2Participants = false;
  final DateTime _callStartTime = DateTime.now();
  Stream? shareStream;
  Stream? videoStream;
  Stream? audioStream;
  Stream? remoteParticipantShareStream;

  bool fullScreen = false;

  // Agent state
  AgentState _agentState = AgentState.idle;

  // Transcript
  final List<TranscriptMessage> transcriptMessages = [];

  // Screen share
  bool _isScreenSharing = false;
  bool _isTogglingScreenShare = false;

  // Local controls
  bool _isMicOn = true;
  bool _isCamOn = false;

  // Permissions
  bool _micPermissionDenied = false;
  bool _camPermissionDenied = false;

  // Device trackers
  String? _selectedAudioDeviceName;
  String? _selectedVideoDeviceName;

  // PiP swap
  bool _isSwapped = false;

  // Chat
  late final TextEditingController _chatController;
  bool _isChatOpen = false;

  // Device menu state
  bool _isMicMenuOpen = false;
  bool _isCamMenuOpen = false;

  String? _activeSpeakerId; // ← ADD THIS
  // // Both cams off — does NOT include screen share (handled separately in build)
  // bool get _bothCamsOff => videoStream == null && !_isCamOn;

  // After
  bool get _bothCamsOff {
    // If local cam is on, definitely not "both off"
    if (videoStream != null || _isCamOn) return false;

    // Check if remote participant has video on
    final remoteParticipant = _joined && meeting.participants.values.isNotEmpty
        ? meeting.participants.values.first
        : null;
    if (remoteParticipant != null) {
      final hasRemoteVideo =
          remoteParticipant.streams.values.any((s) => s.kind == 'video');
      if (hasRemoteVideo) return false;
    }

    return true;
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  Future<void> _dispatchAgent(String meetingId) async {
    if (_isDispatchingAgent) return;

    final agentId = dotenv.env['AGENT_ID']?.trim() ?? '';
    String? versionId = dotenv.env['VERSION_ID']?.trim();

    if (agentId.isEmpty) {
      showSnackBarMessage(
        message: 'Please provide an Agent ID in .env',
        context: context,
      );
      return;
    }

    setState(() => _isDispatchingAgent = true);

    try {
      // Step 1 — fetch latest versionId for this agent only if not present in .env
      if (versionId == null || versionId.isEmpty) {
        final versionsRes = await http.get(
          Uri.parse('https://api.videosdk.live/ai/v1/agents/$agentId/versions'),
          headers: {
            'Authorization': widget.token,
            'Content-Type': 'application/json',
          },
        );

        if (versionsRes.statusCode != 200) {
          _goBackWithError('Failed to fetch agent versions');
          return; // ← stop execution
        }

        final versionsBody =
            jsonDecode(versionsRes.body) as Map<String, dynamic>;
        final versions = versionsBody['versions'] as List<dynamic>?;

        if (versions == null || versions.isEmpty) {
          _goBackWithError('No versions found for agent');
          return; // ← stop execution
        }

        versionId =
            (versions.first as Map<String, dynamic>)['versionId'] as String?;
      }

      if (versionId == null || versionId.isEmpty) {
        _goBackWithError('Agent version ID could not be determined');
        return;
      }

      // Step 2 — dispatch agent
      final dispatchRes = await http.post(
        Uri.parse('https://api.videosdk.live/v2/agent/dispatch'),
        headers: {
          'Authorization': widget.token,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'meetingId': meetingId,
          'agentId': agentId,
          'versionId': versionId,
        }),
      );

      if (dispatchRes.statusCode == 200 || dispatchRes.statusCode == 201) {
        Room room = VideoSDK.createRoom(
          roomId: meetingId,
          token: widget.token,
          displayName: widget.displayName,
          micEnabled: widget.micEnabled,
          camEnabled: false,
          maxResolution: 'hd',
          multiStream: false,
          customCameraVideoTrack: widget.cameraTrack,
          customMicrophoneAudioTrack: widget.micTrack,
          notification: const NotificationInfo(
            title: "Video SDK",
            message: "Video SDK is sharing screen in the meeting",
            icon: "notification_share",
          ),
        );
        registerMeetingEvents(room);
        room.join();
      } else {
        final body = jsonDecode(dispatchRes.body) as Map<String, dynamic>;
        _goBackWithError(body['message'] ?? 'Agent dispatch failed');
        return; // ← stop execution
      }
    } catch (e) {
      _goBackWithError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isDispatchingAgent = false);
    }
  }

// ── helper: show error then navigate back to JoinScreen ──────────
  void _goBackWithError(String message) {
    if (!mounted) return;
    showSnackBarMessage(message: message, context: context);
    // Small delay so the snackbar is visible before navigation
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const JoinScreen()),
        (route) => false,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _isMicOn = widget.micEnabled;
    _isCamOn = widget.camEnabled;
    _chatController = TextEditingController();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _checkPermissions();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _dispatchAgent("3ubt-utex-8knt");
      }
    });
  }

  Future<void> _checkPermissions() async {
    final mic = await Permission.microphone.status;
    final cam = await Permission.camera.status;
    setState(() {
      _micPermissionDenied = mic.isDenied || mic.isPermanentlyDenied;
      _camPermissionDenied = cam.isDenied || cam.isPermanentlyDenied;
    });
  }

  Future<void> _toggleMic() async {
    var status = await Permission.microphone.status;
    if (status.isDenied) {
      status = await Permission.microphone.request();
    }
    if (status.isPermanentlyDenied) {
      setState(() => _micPermissionDenied = true);
      await showPermissionDeniedDialog(context, isMic: true);
      return;
    }
    if (status.isGranted) {
      setState(() => _micPermissionDenied = false);
      if (_isMicOn) {
        meeting.muteMic();
      } else {
        meeting.unmuteMic();
      }
      setState(() => _isMicOn = !_isMicOn);
    }
  }

  Future<void> _toggleCam() async {
    widget.isVideoPermissionAsked = true;
    var status = await Permission.camera.status;
    if (status.isDenied) {
      status = await Permission.camera.request();
    }

    if (status.isDenied || status.isPermanentlyDenied) {
      setState(() => _camPermissionDenied = true);
    }

    if (status.isPermanentlyDenied) {
      await showPermissionDeniedDialog(context, isMic: false);
      return;
    }

    if (status.isGranted) {
      setState(() => _camPermissionDenied = false);
      if (_isCamOn) {
        meeting.disableCam();
      } else {
        meeting.enableCam();
      }
      setState(() => _isCamOn = !_isCamOn);
    }
  }

  // ─────────────────────────────────────────────
//  Speaker picker — bottom sheet
// ─────────────────────────────────────────────
  Future<void> _showSpeakerBottomSheet() async {
    // Collect audio-output devices (same list the chevron used)
    final List<AudioDeviceInfo> speakers = [];
    final allDevices = await VideoSDK.getAudioDevices();
    if (allDevices != null) {
      for (final d in allDevices) {
        if (d.kind == 'audiooutput') speakers.add(d);
      }
    }
    if (speakers.isEmpty || !mounted) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  children: [
                    Text(
                      'Audio Output',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              ...List.generate(speakers.length, (i) {
                final isSelected =
                    speakers[i].label == _selectedAudioDeviceName ||
                        (_selectedAudioDeviceName == null && i == 0);
                return InkWell(
                  onTap: () {
                    setState(
                        () => _selectedAudioDeviceName = speakers[i].label);
                    meeting.switchAudioDevice(speakers[i]);
                    Navigator.of(ctx).pop();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            speakers[i].label,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.75),
                              fontSize: 15,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_outlined,
                              color: Color(0xFF7C3AED), size: 18),
                      ],
                    ),
                  ),
                );
              }),
              SizedBox(
                height: MediaQuery.of(context).padding.bottom + 12,
              ),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────
  //  Screen share toggle
  // ─────────────────────────────────────────────
  Future<void> _toggleScreenShare() async {
    if (_isTogglingScreenShare) return;
    setState(() => _isTogglingScreenShare = true);

    try {
      if (shareStream != null) {
        // Delay prevents ConcurrentModificationException in VideoSDK's
        // native AudioRecordThread on Android
        await Future.delayed(const Duration(milliseconds: 300));
        meeting.disableScreenShare();
        setState(() => _isScreenSharing = false);
      } else {
        if (!kIsWeb && (Platform.isWindows || Platform.isMacOS)) {
          final source = await selectScreenSourceDialog(context);
          if (source != null) {
            meeting.enableScreenShare(source: source, enableAudio: true);
            setState(() => _isScreenSharing = true);
          }
        } else if (!kIsWeb && Platform.isAndroid) {
          meeting.enableScreenShare(enableAudio: true);
          setState(() => _isScreenSharing = true);
        } else {
          meeting.enableScreenShare();
          setState(() => _isScreenSharing = true);
        }
      }
    } finally {
      await Future.delayed(const Duration(milliseconds: 500));
      setState(() => _isTogglingScreenShare = false);
    }
  }

  Future<DesktopCapturerSource?> selectScreenSourceDialog(
      BuildContext context) async {
    final source = await showDialog<DesktopCapturerSource>(
      context: context,
      builder: (context) => ScreenSelectDialog(meeting: meeting),
    );
    return source;
  }

  // ─────────────────────────────────────────────
  //  Mic chevron
  // ─────────────────────────────────────────────
  Future<void> _onMicChevron(BuildContext chevronCtx) async {
    if (!_isMicOn) return;
    final devices = mics ?? [];
    if (devices.isEmpty) return;
    final names = devices.map((d) => d.label).toList();

    setState(() => _isMicMenuOpen = true);
    await showDevicePickerMenu(
      anchorContext: chevronCtx,
      deviceNames: names,
      selectedDeviceName: _selectedAudioDeviceName ?? names.first,
      onSelect: (i) {
        setState(() => _selectedAudioDeviceName = names[i]);
        meeting.changeMic(devices[i]);
      },
    );
    setState(() => _isMicMenuOpen = false);
  }

  // bool get _shouldShowPip {
  //   // During screen share → show PiP if remote cam is on
  //   if (shareStream != null) {
  //     final remoteParticipant = meeting.participants.values.isNotEmpty
  //         ? meeting.participants.values.first
  //         : null;
  //     if (remoteParticipant == null) return false;
  //     return remoteParticipant.streams.values.any((s) => s.kind == 'video');
  //   }

  //   // Normal mode → show PiP only when local cam is on
  //   return videoStream != null;
  // }

  bool get _shouldShowPip {
    // During screen share → show PiP if remote cam OR local cam is on
    if (shareStream != null) {
      final remoteParticipant = meeting.participants.values.isNotEmpty
          ? meeting.participants.values.first
          : null;
      final hasRemoteVideo = remoteParticipant != null &&
          remoteParticipant.streams.values.any((s) => s.kind == 'video');

      return hasRemoteVideo ||
          videoStream != null; // ← was: return hasRemoteVideo
    }

    // Normal mode → show PiP only when local cam is on
    return videoStream != null;
  }

  // ─────────────────────────────────────────────
  //  Cam chevron
  // ─────────────────────────────────────────────
  Future<void> _onCamChevron(BuildContext chevronCtx) async {
    if (!_isCamOn) return;
    final devices = cameras ?? [];
    if (devices.isEmpty) return;
    final names = devices.map((d) => d.label).toList();

    setState(() => _isCamMenuOpen = true);
    await showDevicePickerMenu(
      anchorContext: chevronCtx,
      deviceNames: names,
      selectedDeviceName: _selectedVideoDeviceName ??
          (devices.isNotEmpty ? devices.first.label : null),
      onSelect: (i) {
        setState(() => _selectedVideoDeviceName = names[i]);
        meeting.changeCam(devices[i]);
        setState(() {
          isFrontCam = devices[i].label.toLowerCase().contains("front") ||
              devices[i].label.toLowerCase().contains("user");
        });
      },
    );
    setState(() => _isCamMenuOpen = false);
  }

  Stream? _getRemoteVideoStream() {
    final remoteParticipant = meeting.participants.values.isNotEmpty
        ? meeting.participants.values.first
        : null;
    if (remoteParticipant == null) return null;
    try {
      return remoteParticipant.streams.values
          .firstWhere((s) => s.kind == 'video');
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (!_joined) {
      return _moreThan2Participants
          ? ParticipantLimitReached(meeting: meeting)
          : const WaitingToJoin();
    }

    // Screen sharing active → always video UI so PiP is visible
    if (shareStream != null) {
      return _buildVideoMeetingUI();
    }

    if (_bothCamsOff) {
      return _buildOrbMeetingUI();
    }

    return _buildVideoMeetingUI();
  }

  // ─────────────────────────────────────────────
  //  Screen share overlay (reusable)
  // ─────────────────────────────────────────────
  Widget _buildScreenShareOverlay() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.screen_share_outlined,
            color: Colors.white,
            size: 36,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          "You're sharing your screen with everyone",
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _toggleScreenShare,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.stop_screen_share_outlined,
                    color: Colors.white.withOpacity(0.9), size: 16),
                const SizedBox(width: 6),
                Text(
                  'Stop Sharing',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  //  Bottom bar (unified chat + controls)
  // ─────────────────────────────────────────────
  Widget _buildBottomBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Chat input — toggles on/off
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _isChatOpen
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 10, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _chatController,
                            autofocus: true,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 15),
                            decoration: InputDecoration(
                              hintText: 'Type something...',
                              hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.35),
                                fontSize: 15,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onSubmitted: _sendChatMessage,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _sendChatMessage(_chatController.text),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.send_outlined,
                              color: Colors.white.withOpacity(0.7),
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // Divider — only when chat open
          if (_isChatOpen)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Divider(
                color: Colors.white.withOpacity(0.07),
                height: 12,
                thickness: 1,
              ),
            ),

          // Controls row
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                CallTimer(startTime: _callStartTime),
                const SizedBox(width: 8),
                BarButton(
                  icon: _isMicOn ? Icons.mic_outlined : Icons.mic_off_outlined,
                  onTap: _toggleMic,
                  isOff: !_isMicOn,
                  showChevron: false,
                  isMenuOpen: _isMicMenuOpen,
                  showPermissionWarning: _micPermissionDenied,
                  onChevronTap: _onMicChevron,
                  showSpeakerIndicator: true, // ← ADD
                  isSpeaking: _isMicOn &&
                      _activeSpeakerId == meeting.localParticipant.id, // ← ADD
                ),
                const SizedBox(width: 6),

                // Camera — 56×32
                BarButton(
                  icon: _isCamOn
                      ? Icons.videocam_outlined
                      : Icons.videocam_off_outlined,
                  onTap: _toggleCam,
                  isOff: !_isCamOn,
                  showChevron: true,
                  isMenuOpen: _isCamMenuOpen,
                  showPermissionWarning:
                      widget.isVideoPermissionAsked && _camPermissionDenied,
                  onChevronTap: _onCamChevron,
                ),
                const SizedBox(width: 6),

                // Screen share — 32×32
                BarButton(
                  icon: _isScreenSharing
                      ? Icons.stop_screen_share_outlined
                      : Icons.screen_share_outlined,
                  onTap: _toggleScreenShare,
                ),
                const SizedBox(width: 6),

                // Chat toggle — 32×32
                BarButton(
                  icon: _isChatOpen
                      ? Icons.mark_chat_read_outlined
                      : Icons.chat_outlined,
                  onTap: () {
                    setState(() => _isChatOpen = !_isChatOpen);
                    if (!_isChatOpen) FocusScope.of(context).unfocus();
                  },
                ),

                const Spacer(),

                // End Call — 76×32
                GestureDetector(
                  onTap: () => meeting.end(),
                  child: Container(
                    width: 76,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'End Call',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoMeetingUI() {
    final size = MediaQuery.of(context).size;
    final pipWidth = size.width * 0.30;
    final pipHeight = pipWidth * 1.45;

    final topSafeArea = MediaQuery.of(context).padding.top;

    // Header: "Powered by VideoSDK" (~16) + gap(6) + pill(32) + top offset(8) = ~62
    const headerHeight = 62.0;
    const gapBelowHeader = 18.0;
    final bigViewTop = topSafeArea + 8 + headerHeight + gapBelowHeader;

    // Big view width respecting horizontal padding
    const horizontalPadding = 16.0;
    final bigViewWidth = size.width - (horizontalPadding * 2);
    final bigViewHeight = bigViewWidth * (570 / 370);
    final bool effectivelySwapped = _isSwapped && videoStream != null;

// During screen share: big = share overlay, small = local cam (if on)
    final Widget bigFeed = shareStream != null
        ? _remoteVideoWidget(isPip: false) // renders screen share overlay
        : effectivelySwapped
            ? _localVideoWidget(isPip: false)
            : _remoteVideoWidget(isPip: false);

    final Widget smallFeed = shareStream != null
        ? _localVideoWidget(isPip: true) // renders local cam in PiP
        : effectivelySwapped
            ? _remoteVideoWidget(isPip: true)
            : _localVideoWidget(isPip: true);
    return PopScope(
      onPopInvoked: (didPop) async {
        if (didPop) return;
        _onWillPopScope();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            // Background
            Positioned.fill(child: Container(color: Colors.black)),

            // Big feed — positioned precisely
            Positioned(
              top: bigViewTop,
              left: horizontalPadding,
              right: horizontalPadding,
              height: bigViewHeight,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    // Video feed fills the box
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: (shareStream != null ||
                                (!_isSwapped && videoStream == null))
                            ? null // ← disable tap when screen sharing OR only remote cam showing
                            : () {
                                FocusScope.of(context).unfocus();
                                setState(() => _isSwapped = !_isSwapped);
                              },
                        child: bigFeed,
                      ),
                    ),

                    if (_isSwapped &&
                        _isCamOn &&
                        shareStream == null &&
                        videoStream != null)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: GestureDetector(
                          onTap: () => _showCamSwitchMenu(TapDownDetails()),
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.55),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.flip_camera_ios,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    // PiP — entirely inside big view, top-right with 10dp inset
                    if (_shouldShowPip)
                      Positioned(
                        top: 10,
                        left:
                            _isSwapped ? 10 : null, // remote in PiP → top-left
                        right:
                            _isSwapped ? null : 10, // local in PiP  → top-right
                        width: pipWidth,
                        height: pipHeight,
                        child: GestureDetector(
                          onTap: (shareStream != null ||
                                  (!_isSwapped && videoStream == null))
                              ? null
                              : () => setState(() => _isSwapped = !_isSwapped),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.25),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: Stack(
                                children: [
                                  Positioned.fill(child: smallFeed),
                                  // if (!_isSwapped &&
                                  //         _isCamOn &&
                                  //         shareStream == null
                                  //     ? (videoStream != null &&
                                  //         _getRemoteVideoStream() == null)
                                  //     : !_isSwapped && _isCamOn)
                                  if (_isCamOn &&
                                      videoStream != null &&
                                      !_isSwapped &&
                                      (shareStream == null ||
                                          _getRemoteVideoStream() == null))
                                    Positioned(
                                      top: 6,
                                      right: _isSwapped
                                          ? null
                                          : 6, // PiP (top-right) or big view (top-right)
                                      left: _isSwapped
                                          ? 6
                                          : null, // big view when swapped → top-left of big
                                      child: GestureDetector(
                                        onTap: () => _showCamSwitchMenu(
                                            TapDownDetails()),
                                        child: Container(
                                          padding: const EdgeInsets.all(5),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.black.withOpacity(0.55),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.flip_camera_ios,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Bottom vignette
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

            // Top header
            Positioned(
              top: topSafeArea + 8,
              left: 0,
              right: 0,
              child: TopHeader(
                state: _agentState,
                onSpeakerTap: _showSpeakerBottomSheet,
              ),
            ),

            // Transcript + Bottom bar anchored together
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (transcriptMessages.isNotEmpty)
                    TranscriptView(messages: transcriptMessages),
                  const SizedBox(height: 8),
                  _buildBottomBar(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendChatMessage(String text) {
    final msg = text.trim();
    if (msg.isEmpty) return;
    meeting.pubSub.publish(
      "CHAT",
      msg,
      const PubSubPublishOptions(persist: true),
    );
    _chatController.clear();
    FocusScope.of(context).unfocus();
  }

  Widget _remoteVideoWidget({bool isPip = false}) {
    final remoteParticipant = meeting.participants.values.isNotEmpty
        ? meeting.participants.values.first
        : null;

    Stream? remoteVideoStream;
    if (remoteParticipant != null) {
      try {
        remoteVideoStream = remoteParticipant.streams.values
            .firstWhere((s) => s.kind == 'video');
      } catch (_) {
        remoteVideoStream = null;
      }
    }

    // Screen sharing active → big feed = overlay, PiP = local cam or placeholder
    if (shareStream != null) {
      if (isPip) {
        // PiP shows local cam during screen share, not the overlay
        if (videoStream != null) {
          return RTCVideoView(
            videoStream!.renderer as RTCVideoRenderer,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            mirror: true,
          );
        }
        return Container(
          color: const Color(0xFF2A2A2E),
          child: const Center(
            child: Icon(Icons.videocam_off, color: Colors.white38, size: 32),
          ),
        );
      }

      // Big feed = screen share overlay
      return Container(
        color: Colors.black,
        child: Stack(
          children: [
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
            Center(child: _buildScreenShareOverlay()),
          ],
        ),
      );
    }

    // No remote video → orb
    if (remoteParticipant == null || remoteVideoStream == null) {
      return Container(
        color: Colors.black,
        child: Stack(
          children: [
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
            Center(child: MeetingOrb(agentState: _agentState)),
          ],
        ),
      );
    }

    return RTCVideoView(
      remoteVideoStream.renderer as RTCVideoRenderer,
      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
    );
  }

  Widget _localVideoWidget({bool isPip = false}) {
    if (shareStream != null) {
      // During screen share, PiP slot shows remote cam (or local if remote off)
      final remoteParticipant = meeting.participants.values.isNotEmpty
          ? meeting.participants.values.first
          : null;

      Stream? remoteVideoStream;
      if (remoteParticipant != null) {
        try {
          remoteVideoStream = remoteParticipant.streams.values
              .firstWhere((s) => s.kind == 'video');
        } catch (_) {
          remoteVideoStream = null;
        }
      }

      // Priority 1: remote cam on → show in PiP
      if (remoteVideoStream != null) {
        return RTCVideoView(
          remoteVideoStream.renderer as RTCVideoRenderer,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        );
      }

      // Priority 2: local cam on → show in PiP
      if (videoStream != null) {
        return RTCVideoView(
          videoStream!.renderer as RTCVideoRenderer,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          mirror: true,
        );
      }

      // Priority 3: both off
      return Container(
        color: const Color(0xFF2A2A2E),
        child: const Center(
          child: Icon(Icons.videocam_off, color: Colors.white38, size: 32),
        ),
      );
    }

    // ── Normal mode (no screen share) ──────────────────────────
    if (isPip) {
      // PiP slot = local cam
      if (videoStream == null) {
        return Container(
          color: const Color(0xFF2A2A2E),
          child: const Center(
            child: Icon(Icons.videocam_off, color: Colors.white38, size: 32),
          ),
        );
      }
      return RTCVideoView(
        videoStream!.renderer as RTCVideoRenderer,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        mirror: true,
      );
    }

    // Big slot = local cam (swapped mode)
    if (videoStream == null) {
      return Container(
        color: const Color(0xFF2A2A2E),
        child: const Center(
          child: Icon(Icons.videocam_off, color: Colors.white38, size: 32),
        ),
      );
    }
    return RTCVideoView(
      videoStream!.renderer as RTCVideoRenderer,
      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      mirror: true,
    );
  }

  Future<void> _showCamSwitchMenu(TapDownDetails details) async {
    if (cameras == null || cameras!.length < 2) return;

    VideoDeviceInfo? deviceToSwitch;

    if (isFrontCam) {
      deviceToSwitch = cameras!.firstWhere(
        (cam) => cam.label.toLowerCase() == "back camera",
        orElse: () => cameras!.firstWhere(
          (cam) =>
              cam.label.toLowerCase().contains("back") &&
              !cam.label.toLowerCase().contains("wide"),
          orElse: () => cameras!.firstWhere(
            (cam) => cam.label.toLowerCase().contains("back"),
          ),
        ),
      );
    } else {
      deviceToSwitch = cameras!.firstWhere(
        (cam) =>
            cam.label.toLowerCase().contains("front") ||
            cam.label.toLowerCase().contains("user"),
      );
    }

    meeting.changeCam(deviceToSwitch);

    setState(() {
      isFrontCam = deviceToSwitch!.label.toLowerCase().contains("front") ||
          deviceToSwitch.label.toLowerCase().contains("user");
    });
  }

  Widget _buildOrbMeetingUI() {
    return PopScope(
      onPopInvoked: (didPop) async {
        if (didPop) return;
        _onWillPopScope();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Background
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

            // Top vignette
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

            // Bottom vignette
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 260,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Top header
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 0,
              right: 0,
              child: TopHeader(
                state: _agentState,
                onSpeakerTap: _showSpeakerBottomSheet,
              ),
            ),

            // ✅ FIX 3: Orb stays centered in space ABOVE the keyboard
            Positioned.fill(
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Center(
                  child: MeetingOrb(agentState: _agentState),
                ),
              ),
            ),

            // ✅ FIX 1: Bottom bar lifts with keyboard
            Positioned(
              bottom:
                  MediaQuery.of(context).viewInsets.bottom, // ← changed from 0
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (transcriptMessages.isNotEmpty)
                    TranscriptView(messages: transcriptMessages),
                  const SizedBox(height: 8),
                  _buildBottomBar(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  Meeting events
  // ─────────────────────────────────────────────
  void registerMeetingEvents(Room _meeting) {
    VideoSDK.on(Events.deviceChanged, () async {
      cameras = await VideoSDK.getVideoDevices();
      List<AudioDeviceInfo>? audioDeviceInfo = await VideoSDK.getAudioDevices();
      mics = [];
      if (audioDeviceInfo != null) {
        for (var device in audioDeviceInfo) {
          if (device.kind == 'audioinput') {
            mics?.add(device);
          }
        }
      }
    });
    _meeting.on(Events.speakerChanged, (activeSpeakerId) {
      setState(() => _activeSpeakerId = activeSpeakerId);
    });

    _meeting.on(Events.roomJoined, () async {
      if (_meeting.participants.length > 1) {
        setState(() {
          meeting = _meeting;
          _moreThan2Participants = true;
        });
      } else {
        setState(() {
          meeting = _meeting;
          _joined = true;
        });
        cameras = await VideoSDK.getVideoDevices();
        List<AudioDeviceInfo>? audioDeviceInfo =
            await VideoSDK.getAudioDevices();
        if (audioDeviceInfo != null) {
          for (var device in audioDeviceInfo) {
            if (device.kind == 'audiooutput') {
              mics?.add(device);
            }
          }
        }
        if (kIsWeb || Platform.isWindows || Platform.isMacOS) {
          _meeting.switchAudioDevice(widget.selectedAudioOutputDevice!);
        }
        // subscribeToChatMessages(_meeting);
        _subscribeToAgentEvents(_meeting);
      }
    });

    _meeting.on(Events.roomLeft, (LeaveReason reason) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const JoinScreen()),
        (route) => false,
      );
    });

    _meeting.on(Events.recordingStateChanged, (String status) {
      showSnackBarMessage(
        message:
            "Meeting recording ${status == "RECORDING_STARTING" ? "is starting" : status == "RECORDING_STARTED" ? "started" : status == "RECORDING_STOPPING" ? "is stopping" : "stopped"}",
        context: context,
      );
      setState(() => recordingState = status);
    });

    _meeting.localParticipant.on(Events.streamEnabled, (Stream _stream) {
      if (_stream.kind == 'video') {
        setState(() => videoStream = _stream);
      } else if (_stream.kind == 'audio') {
        setState(() => audioStream = _stream);
      } else if (_stream.kind == 'share') {
        setState(() => shareStream = _stream);
      }
    });

    _meeting.localParticipant.on(Events.streamDisabled, (Stream _stream) {
      if (_stream.kind == 'video' && videoStream?.id == _stream.id) {
        setState(() => videoStream = null);
      } else if (_stream.kind == 'audio' && audioStream?.id == _stream.id) {
        setState(() => audioStream = null);
      } else if (_stream.kind == 'share' && shareStream?.id == _stream.id) {
        setState(() {
          shareStream = null;
          _isScreenSharing = false;
        });
      }
    });

    _meeting.on(Events.presenterChanged, (_activePresenterId) {
      Participant? activePresenter = _meeting.participants[_activePresenterId];
      Stream? _stream =
          activePresenter?.streams.values.singleWhere((e) => e.kind == "share");
      setState(() => remoteParticipantShareStream = _stream);
    });

    _meeting.on(Events.participantLeft, (participant) {
      if (_moreThan2Participants) {
        if (_meeting.participants.length < 2) {
          setState(() {
            _joined = true;
            _moreThan2Participants = false;
          });
          subscribeToChatMessages(_meeting);
        }
      }
    });

    _meeting.on(
      Events.error,
      (error) => showSnackBarMessage(
        message: "${error['name']} :: ${error['message']}",
        context: context,
      ),
    );
  }

  void _subscribeToAgentEvents(Room _meeting) {
    _listenToParticipantAgentEvents(_meeting.localParticipant);
    // Subscribe to all already-joined participants
    for (var participant in _meeting.participants.values) {
      _listenToParticipantAgentEvents(participant);
    }
    _meeting.on(Events.participantJoined, (Participant participant) {
      _listenToParticipantAgentEvents(participant);
    });
  }

  void _listenToParticipantAgentEvents(Participant participant) {
    participant.on(Events.agentStateChanged, (dynamic state) {
      setState(() => _agentState = parseAgentState(state));
    });

    participant.on(Events.agentTranscriptionReceived, (
      TranscriptionSegment data,
      Participant participant,
    ) {
      String text = '';
      String senderName = participant.displayName;
      text = data.text!;
      if (text.isNotEmpty) {
        setState(() {
          transcriptMessages.add(
            TranscriptMessage(senderName: senderName, text: text),
          );
          if (transcriptMessages.length > 20) {
            transcriptMessages.removeAt(0);
          }
        });
      }
    });

    // Rebuild PiP when remote participant's camera changes
    participant.on(Events.streamEnabled, (Stream stream) {
      if (stream.kind == 'video') {
        setState(() {});
      }
    });

    participant.on(Events.streamDisabled, (Stream stream) {
      if (stream.kind == 'video') {
        setState(() {});
      }
    });
  }

  void subscribeToChatMessages(Room meeting) {
    meeting.pubSub.subscribe("CHAT", (message) {
      if (message.senderId != meeting.localParticipant.id) {
        if (mounted && showChatSnackbar) {
          showSnackBarMessage(
            message: message.senderName + ": " + message.message,
            context: context,
          );
        }
      }
    });
  }

  Future<bool> _onWillPopScope() async {
    meeting.leave();
    return true;
  }

  @override
  void dispose() {
    _chatController.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }
}
