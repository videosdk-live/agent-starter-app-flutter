// ignore_for_file: non_constant_identifier_names

import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:agent_starter_flutter/utils/toast.dart';

String? _VIDEOSDK_API_ENDPOINT = 'https://api.videosdk.live/v2';
Future<String> fetchToken(BuildContext context) async {
  if (!dotenv.isInitialized) {
    // Load Environment variables
    await dotenv.load(fileName: ".env");
  }
  final String? _AUTH_URL = dotenv.env['AUTH_URL'];
  String? _AUTH_TOKEN = dotenv.env['AUTH_TOKEN'];

  if ((_AUTH_TOKEN?.isEmpty ?? true) && (_AUTH_URL?.isEmpty ?? true)) {
    showSnackBarMessage(
        message: "Please set the environment variables", context: context);
    throw Exception("Either AUTH_TOKEN or AUTH_URL is not set in .env file");
  }

  if ((_AUTH_TOKEN?.isNotEmpty ?? false) && (_AUTH_URL?.isNotEmpty ?? false)) {
    showSnackBarMessage(
        message: "Please set only one environment variable", context: context);
    throw Exception("Either AUTH_TOKEN or AUTH_URL can be set in .env file");
  }

  if (_AUTH_URL?.isNotEmpty ?? false) {
    final Uri getTokenUrl = Uri.parse('$_AUTH_URL/get-token');
    final http.Response tokenResponse = await http.get(getTokenUrl);
    _AUTH_TOKEN = json.decode(tokenResponse.body)['token'];
  }

  return _AUTH_TOKEN ?? "";
}

Future<String> createMeeting(String _token) async {
  final Uri getMeetingIdUrl = Uri.parse('$_VIDEOSDK_API_ENDPOINT/rooms');
  final http.Response meetingIdResponse =
      await http.post(getMeetingIdUrl, headers: {
    "Authorization": _token,
  });

  if (meetingIdResponse.statusCode != 200) {
    throw Exception(json.decode(meetingIdResponse.body)["error"]);
  }
  var meetingID = json.decode(meetingIdResponse.body)['roomId'];
  return meetingID;
}

Future<bool> validateMeeting(String token, String meetingId) async {
  final Uri validateMeetingUrl =
      Uri.parse('$_VIDEOSDK_API_ENDPOINT/rooms/validate/$meetingId');

  final http.Response validateMeetingResponse =
      await http.get(validateMeetingUrl, headers: {
    "Authorization": token,
  });

  if (validateMeetingResponse.statusCode != 200) {
    throw Exception(json.decode(validateMeetingResponse.body)["error"]);
  }

  return validateMeetingResponse.statusCode == 200;
}
