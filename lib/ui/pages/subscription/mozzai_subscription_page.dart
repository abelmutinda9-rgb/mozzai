import 'dart:async';
import 'package:flutter/material.dart';
import 'package:animestream/core/app/runtimeDatas.dart';
import 'package:animestream/core/services/mozzai_subscription_service.dart';
import 'package:animestream/ui/models/snackBar.dart';

enum PaymentFlowState { idle, initiating, waitingForPin, success, error }

class MozzaiSubscriptionPage extends StatefulWidget {
  final VoidCallback? onSubscriptionActivated;
  final bool isModal;

  const MozzaiSubscriptionPage({
    super.key,
    this.onSubscriptionActivated,
    this.isModal = false,
  });

  @override
  State<MozzaiSubscriptionPage> createState() => _MozzaiSubscriptionPageState();
}

class _MozzaiSubscriptionPageState extends State<MozzaiSubscriptionPage> {
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _payButtonFocusNode = FocusNode();

  PaymentFlowState _flowState = PaymentFlowState.idle;
  String _statusMessage = '';
  String _errorMessage = '';
  String _deviceId = '';
  int _secondsRemaining = 60;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _loadDeviceAndSubscription();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    _payButtonFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadDeviceAndSubscription() async {
    try {
      final devId = await MozzaiSubscriptionService.instance.getDeviceId();
      if (mounted) setState(() => _deviceId = devId);
    } catch (_) {
      if (mounted) setState(() => _errorMessage = 'Secure device registration is unavailable on this device. Premium access cannot be verified.');
      return;
    }
    await MozzaiSubscriptionService.instance.verifySubscription();
    if (mounted) setState(() {});
  }

  void _startCountdown() {
    _secondsRemaining = 60;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _initiatePayment() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length < 9) {
      floatingSnackBar("Please enter a valid M-Pesa phone number (e.g. 0712345678)");
      return;
    }

    setState(() {
      _flowState = PaymentFlowState.initiating;
      _errorMessage = '';
      _statusMessage = 'Sending M-Pesa STK push request...';
    });

    final res = await MozzaiSubscriptionService.instance.initiateMpesaPayment(phone);

    if (!mounted) return;

    if (res['ok'] == true) {
      setState(() {
        _flowState = PaymentFlowState.waitingForPin;
        _statusMessage = 'M-Pesa STK Push sent to $phone.\nEnter your M-Pesa PIN on your phone to complete.';
      });
      _startCountdown();

      // Poll backend for payment callback verification
      final activated = await MozzaiSubscriptionService.instance.pollForActivation(
        timeout: const Duration(seconds: 60),
      );

      _countdownTimer?.cancel();

      if (!mounted) return;

      if (activated) {
        setState(() {
          _flowState = PaymentFlowState.success;
          _statusMessage = 'Payment verified! MOZZAI Premium is now active for 30 days.';
        });
        floatingSnackBar("MOZZAI Premium Activated!");
        widget.onSubscriptionActivated?.call();
      } else {
        setState(() {
          _flowState = PaymentFlowState.error;
          _errorMessage = 'Payment was not confirmed within 60 seconds. If you entered your PIN, tap Refresh Status below.';
        });
      }
    } else {
      setState(() {
        _flowState = PaymentFlowState.error;
        _errorMessage = res['error']?.toString() ?? 'Failed to initiate M-Pesa STK push.';
      });
    }
  }

  Future<void> _refreshStatus() async {
    setState(() {
      _statusMessage = 'Checking subscription status...';
    });
    final sub = await MozzaiSubscriptionService.instance.verifySubscription();
    if (!mounted) return;
    if (sub.isPremium) {
      setState(() {
        _flowState = PaymentFlowState.success;
        _statusMessage = 'MOZZAI Premium is active (${sub.daysRemaining} days remaining)';
      });
      floatingSnackBar("MOZZAI Premium Active!");
      widget.onSubscriptionActivated?.call();
    } else {
      setState(() {
        _flowState = PaymentFlowState.idle;
      });
      floatingSnackBar("No active premium subscription detected for this device.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final sub = MozzaiSubscriptionService.instance.subscriptionNotifier.value;
    final isPremium = sub?.isPremium == true;

    return Scaffold(
      backgroundColor: appTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: appTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: appTheme.textMainColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "MOZZAI Premium",
          style: TextStyle(
            color: appTheme.textMainColor,
            fontFamily: "Poppins",
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: appTheme.accentColor),
            tooltip: "Refresh Status",
            onPressed: _refreshStatus,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeaderCard(isPremium, sub),
                const SizedBox(height: 20),
                if (!isPremium) ...[
                  _buildPlanCard(),
                  const SizedBox(height: 20),
                  _buildPaymentForm(),
                ] else ...[
                  _buildActivePremiumCard(sub!),
                  const SizedBox(height: 20),
                  _buildPaymentForm(),
                ],
                const SizedBox(height: 24),
                _buildDeviceFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(bool isPremium, MozzaiSubscription? sub) {
    final bool isTrial = sub?.isTrial == true;
    final String badgeLabel = isPremium
        ? (isTrial ? "FREE TRIAL ACTIVE" : "MOZZAI PREMIUM ACTIVE")
        : (sub?.status == 'expired' ? "TRIAL / PLAN EXPIRED" : "MOZZAI ACCESS");

    final String titleText = isPremium
        ? (isTrial
            ? "2-Day Free Trial (${sub?.daysRemaining ?? 0}d remaining)"
            : "Premium Active (${sub?.daysRemaining ?? 0}d remaining)")
        : (sub?.status == 'expired'
            ? "Free Trial Expired"
            : "Unlock Unlimited Streaming");

    final String subText = isPremium
        ? "Expires on: ${sub?.expiresAt?.toLocal().toString().split('.')[0] ?? 'N/A'}"
        : (sub?.status == 'expired'
            ? "Your 2-day trial has ended. Subscribe for KSh 70 to continue."
            : "2-Day Free Trial on first install • KSh 70 / 30 Days renewal");

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            isPremium
                ? (isTrial ? Colors.cyan.withOpacity(0.2) : appTheme.accentColor.withOpacity(0.25))
                : Colors.redAccent.withOpacity(0.15),
            appTheme.backgroundSubColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPremium
              ? (isTrial ? Colors.cyanAccent : Colors.amber)
              : (sub?.status == 'expired' ? Colors.redAccent : appTheme.accentColor.withOpacity(0.4)),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isPremium
                  ? (isTrial ? Colors.cyan.withOpacity(0.2) : Colors.amber.withOpacity(0.2))
                  : Colors.redAccent.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPremium
                  ? (isTrial ? Icons.hourglass_top_rounded : Icons.workspace_premium_rounded)
                  : Icons.lock_outline_rounded,
              color: isPremium ? (isTrial ? Colors.cyanAccent : Colors.amber) : Colors.redAccent,
              size: 40,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  badgeLabel,
                  style: TextStyle(
                    color: isPremium ? (isTrial ? Colors.cyanAccent : Colors.amber) : Colors.redAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  titleText,
                  style: TextStyle(
                    color: appTheme.textMainColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: "Poppins",
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subText,
                  style: TextStyle(
                    color: appTheme.textSubColor,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: appTheme.backgroundSubColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "MOZZAI Premium Plan",
                style: TextStyle(
                  color: appTheme.textMainColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: appTheme.accentColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "KSh 70 / 30 Days",
                  style: TextStyle(
                    color: appTheme.onAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildFeatureItem(Icons.card_giftcard_rounded, "Automatic 2-day free trial on first install (device-bound)"),
          _buildFeatureItem(Icons.play_circle_fill_rounded, "Stream all anime series, movies, and episodes"),
          _buildFeatureItem(Icons.hd_rounded, "Full HD 1080p and high-bitrate streaming"),
          _buildFeatureItem(Icons.download_for_offline_rounded, "Fast downloading and offline viewing"),
          _buildFeatureItem(Icons.tv_rounded, "First-class Android TV remote and phone support"),
          _buildFeatureItem(Icons.no_accounts_rounded, "No password or email registration required"),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: appTheme.accentColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: appTheme.textMainColor,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: appTheme.backgroundSubColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: appTheme.accentColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Pay with M-Pesa",
            style: TextStyle(
              color: appTheme.textMainColor,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Enter your Safaricom M-Pesa number. You will receive an instant STK prompt on your phone to enter your PIN.",
            style: TextStyle(
              color: appTheme.textSubColor,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phoneController,
            focusNode: _phoneFocusNode,
            keyboardType: TextInputType.phone,
            style: TextStyle(
              color: appTheme.textMainColor,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: appTheme.backgroundColor,
              prefixIcon: Icon(Icons.phone_android_rounded, color: appTheme.accentColor),
              hintText: "e.g. 0712345678",
              hintStyle: TextStyle(color: appTheme.textSubColor.withOpacity(0.6)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: appTheme.accentColor, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_flowState == PaymentFlowState.initiating || _flowState == PaymentFlowState.waitingForPin) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: appTheme.backgroundColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(
                    _statusMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: appTheme.textMainColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Waiting for M-Pesa confirmation (${_secondsRemaining}s)...",
                    style: TextStyle(
                      color: appTheme.accentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_errorMessage.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.4)),
              ),
              child: Text(
                _errorMessage,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),
          ],
          ElevatedButton(
            focusNode: _payButtonFocusNode,
            style: ElevatedButton.styleFrom(
              backgroundColor: appTheme.accentColor,
              foregroundColor: appTheme.onAccent,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 4,
            ),
            onPressed: (_flowState == PaymentFlowState.initiating || _flowState == PaymentFlowState.waitingForPin)
                ? null
                : _initiatePayment,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.payment_rounded, color: appTheme.onAccent),
                const SizedBox(width: 10),
                Text(
                  "Pay KSh 70 with M-Pesa",
                  style: TextStyle(
                    color: appTheme.onAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivePremiumCard(MozzaiSubscription sub) {
    final bool isTrial = sub.isTrial;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: appTheme.backgroundSubColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isTrial ? Colors.cyanAccent.withOpacity(0.3) : Colors.greenAccent.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                isTrial ? Icons.timer_outlined : Icons.check_circle_rounded,
                color: isTrial ? Colors.cyanAccent : Colors.greenAccent,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                isTrial ? "2-Day Free Trial Active" : "MOZZAI Premium Active",
                style: TextStyle(
                  color: appTheme.textMainColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            isTrial
                ? "Your 2-day free trial is currently active on this device. Reinstalling or clearing data will not reset your trial. Once the 2 days end, pay KSh 70 to continue streaming."
                : "Your MOZZAI Premium subscription is active on this device. You have full access to stream any anime at maximum quality.",
            style: TextStyle(color: appTheme.textSubColor, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appTheme.backgroundSubColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.perm_device_information_rounded, size: 16, color: appTheme.textSubColor),
              const SizedBox(width: 8),
              Text(
                "Bound Device ID",
                style: TextStyle(
                  color: appTheme.textSubColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SelectableText(
            _deviceId.isNotEmpty ? _deviceId : "Generating...",
            style: TextStyle(
              color: appTheme.textSubColor.withOpacity(0.8),
              fontFamily: "Rubik",
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "This subscription is associated with this device record and cannot be transferred.",
            style: TextStyle(
              color: appTheme.textSubColor.withOpacity(0.6),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
