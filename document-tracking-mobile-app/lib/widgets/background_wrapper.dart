import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

class BackgroundWrapper extends StatefulWidget {
  final Widget child;

  const BackgroundWrapper({super.key, required this.child});

  static StreamSubscription<List<ConnectivityResult>>? _connectionSubscription;

  static Future<void> stopConnectionSubscription() async {
    if (_connectionSubscription != null) {
      await _connectionSubscription!.cancel();
      _connectionSubscription = null;
      debugPrint("Internet Monitoring Stopped.");
    }
  }

  @override
  State<BackgroundWrapper> createState() => _BackgroundWrapperState();
}

class _BackgroundWrapperState extends State<BackgroundWrapper> with WidgetsBindingObserver{
  bool _isFirstCheck = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    BackgroundWrapper._connectionSubscription?.cancel();

    BackgroundWrapper._connectionSubscription = 
        Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> result) {
      _handleConnectionChange(result);
    });
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
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            msg,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              fontFamily: 'Inter',
            ),
          ),
        ),
      ),
      displayDuration: const Duration(seconds: 3),
      curve: Curves.elasticOut, 
      reverseCurve: Curves.linear,
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      // Kapag ang app ay tuluyan nang kakalasin (Exit)
      BackgroundWrapper.stopConnectionSubscription();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.black,
          image: DecorationImage(
            image: AssetImage("assets/images/background_image.png"),
            fit: BoxFit.cover,
            opacity: 1.0,
          ),
        ),
        child: widget.child,
      ),
    );
  }
}