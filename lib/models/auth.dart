import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shop/data/store.dart';
import 'package:shop/exceptions/auth_exception.dart';

class Auth with ChangeNotifier {
  String? _token;
  String? _email;
  String? _userId;
  DateTime? _expiryDate;
  Timer? _logoutTimer;

  bool get isAuth {
    final isValid = _expiryDate != null && _expiryDate!.isAfter(DateTime.now());
    return _token != null && isValid;
  }

  String? get email => isAuth ? _email : null;

  String? get userId => isAuth ? _userId : null;

  String? get token => isAuth ? _token : null;

  Future<void> _authenticate(
      String email, String password, String urlSegment) async {
    final url =
        'https://identitytoolkit.googleapis.com/v1/accounts:$urlSegment?key=AIzaSyAsYmw39Vp2SUDgrxH8JcaYmK3d_LJ0A0E';
    final response = await http.post(
      Uri.parse(url),
      body: jsonEncode(
        {
          'email': email,
          'password': password,
          'returnSecureToken': true,
        },
      ),
    );
    final responseData = jsonDecode(response.body);
    if (responseData['error'] != null) {
      throw AuthException(responseData['error']['message']);
    }
    _token = responseData['idToken'];
    _email = responseData['email'];
    _userId = responseData['localId'];
    _expiryDate = DateTime.now().add(
      Duration(
        seconds: int.parse(
          responseData['expiresIn'],
        ),
      ),
    );

    Store.saveMap('userData', {
      'token': _token,
      'email': _email,
      'userId': _userId,
      'expiryDate': _expiryDate!.toIso8601String(),
    });

    _autoLogout();
    notifyListeners();
  }

  Future<void> tryAutoLogin() async {
    if (isAuth) return;
    final userData = await Store.getMap('userData');
    if (userData.isEmpty) return;
    final expiryDate = DateTime.parse(userData['expiryDate']);
    if (expiryDate.isBefore(DateTime.now())) return;
    _token = userData['token'];
    _email = userData['email'];
    _userId = userData['userId'];
    _expiryDate = expiryDate;
    _autoLogout();
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    return _authenticate(email, password, 'signInWithPassword');
  }

  Future<void> signup(String email, String password) async {
    return _authenticate(email, password, 'signUp');
  }

  void logout() {
    _token = null;
    _email = null;
    _userId = null;
    _expiryDate = null;
    _clearLogoutTimer();
    Store.removeString('userData').then((value) => notifyListeners());
  }

  void _clearLogoutTimer() {
    if (_logoutTimer != null) {
      _logoutTimer!.cancel();
      _logoutTimer = null;
    }
  }

  void _autoLogout() {
    _clearLogoutTimer();
    final timeToLogout = _expiryDate!.difference(DateTime.now()).inSeconds;
    _logoutTimer = Timer(Duration(seconds: timeToLogout), logout);
  }
}
