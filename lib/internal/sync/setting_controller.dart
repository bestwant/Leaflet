import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:loggy/loggy.dart';
import 'package:potato_notes/internal/providers.dart';

import 'note_controller.dart';

class SettingController {
  static const SETTINGS_PREFIX = NoteController.NOTES_PREFIX;

  static Future<String> get(String key) async {
    try {
      String token = await prefs.getToken();
      var url = "${prefs.apiUrl}$SETTINGS_PREFIX/setting/$key";
      Loggy.v(message: "Going to send GET to " + url);
      Response getResult = await dio.get(
        url,
        options: Options(headers: {"Authorization": "Bearer " + token}),
      );
      Loggy.d(
          message:
              "($key get) Server responded with (${getResult.statusCode}): " +
                  getResult.data);
      return NoteController.handleResponse(getResult);
    } on SocketException {
      throw ("Could not connect to server");
    } catch (e) {
      throw (e);
    }
  }

  static Future<String> set(String key, String value) async {
    try {
      String token = await prefs.getToken();
      var url = "${prefs.apiUrl}$SETTINGS_PREFIX/setting/$key";
      Loggy.v(message: "Going to send PUT to " + url);
      Response setResult = await dio.put(
        url,
        data: value,
        options: Options(headers: {"Authorization": "Bearer " + token}),
      );
      Loggy.d(
          message:
          "($key set) Server responded with (${setResult.statusCode}): " +
              setResult.data);
      return NoteController.handleResponse(setResult);
    } on SocketException {
      throw ("Could not connect to server");
    } catch (e) {
      throw (e);
    }
  }

  static Future<Map<String, String>> getChanged(int lastUpdated) async {
    try {
      String token = await prefs.getToken();
      String url =
          "${prefs
          .apiUrl}$SETTINGS_PREFIX/setting/changed?last_updated=$lastUpdated";
      Loggy.v(message: "Going to send GET to " + url);
      Response getResult = await dio.get(url,
          options: Options(headers: {"Authorization": "Bearer " + token}));
      Loggy.d(
          message:
          "(getChanged) Server responded with (${getResult.statusCode}): " +
              getResult.data);
      var body = NoteController.handleResponse(getResult);
      Map<String, dynamic> listChanged = json.decode(body);
      return listChanged.map((key, value) => MapEntry(key, value.toString()));
    } on SocketException {
      throw ("Could not connect to server");
    }
  }
}
