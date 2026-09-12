import 'dart:async';
import 'dart:html' as html; 

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

class AppBackground extends StatefulWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  static StreamSubscription<List<ConnectivityResult>>? _connectionSubscription;

  static Future<void> stopConnectionSubscription() async {
    if (_connectionSubscription != null) {
      await _connectionSubscription!.cancel();
      _connectionSubscription = null;
      debugPrint("Web App: Internet Monitoring Stopped.");
    }
  }

  @override
  State<AppBackground> createState() => _AppBackgroundState();
}

class _AppBackgroundState extends State<AppBackground> {
  bool _isFirstCheck = true;
  StreamSubscription? _webExitSubscription;

  @override
  void initState() {
    super.initState();
    
    AppBackground.stopConnectionSubscription();

    AppBackground._connectionSubscription = 
        Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> result) {
      _handleConnectionChange(result);
    });

    _webExitSubscription = html.window.onBeforeUnload.listen((event) {
      AppBackground.stopConnectionSubscription();
    });
  }

  @override
  void dispose() {
    _webExitSubscription?.cancel();
    AppBackground.stopConnectionSubscription();
    super.dispose();
  }

  void _handleConnectionChange(List<ConnectivityResult> result) {
    if (result.contains(ConnectivityResult.none)) {
      _showTopNotification("No Internet Connection. Please check your network.", Colors.redAccent);
    } else {
      if (!_isFirstCheck) {
        _showTopNotification("Back Online! System is ready.", Colors.green);
      }
    }
    _isFirstCheck = false;
  }

  void _showTopNotification(String msg, Color color) {
    if (!mounted) return;

    showTopSnackBar(
      Overlay.of(context),
      Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          decoration: BoxDecoration(
            color: color.withOpacity(0.9),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Text(
            msg,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
      displayDuration: const Duration(seconds: 4),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.black,
        image: DecorationImage(
          image: AssetImage("assets/images/other-office-background.png"),
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
      ),
      child: widget.child,
    );
  }
}