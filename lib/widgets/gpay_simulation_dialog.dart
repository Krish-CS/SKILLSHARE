import 'package:flutter/material.dart';
import 'dart:async';

/// Google Pay Simulation Dialog
/// Simulates a Google Pay payment flow with UPI ID entry and success animation.
class GPaySimulationDialog extends StatefulWidget {
  final double amount;
  final String recipientName;
  final String description;
  final void Function(String transactionId) onSuccess;
  final VoidCallback? onCancel;

  const GPaySimulationDialog({
    super.key,
    required this.amount,
    required this.recipientName,
    required this.description,
    required this.onSuccess,
    this.onCancel,
  });

  static Future<String?> show(
    BuildContext context, {
    required double amount,
    required String recipientName,
    required String description,
  }) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => GPaySimulationDialog(
        amount: amount,
        recipientName: recipientName,
        description: description,
        onSuccess: (txnId) => Navigator.of(context).pop(txnId),
        onCancel: () => Navigator.of(context).pop(null),
      ),
    );
  }

  @override
  State<GPaySimulationDialog> createState() => _GPaySimulationDialogState();
}

class _GPaySimulationDialogState extends State<GPaySimulationDialog>
    with SingleTickerProviderStateMixin {
  final _upiController = TextEditingController();
  _PayStep _step = _PayStep.enter;
  String? _upiError;
  late AnimationController _animController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _upiController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _onPay() {
    // Unfocus the UPI TextField before setState changes to prevent
    // Flutter Web 'targetElement == domElement' assertion error.
    FocusManager.instance.primaryFocus?.unfocus();
    final upi = _upiController.text.trim();
    if (upi.isEmpty || !upi.contains('@')) {
      setState(() => _upiError = 'Enter a valid UPI ID (e.g. name@okaxis)');
      return;
    }
    setState(() {
      _upiError = null;
      _step = _PayStep.processing;
    });

    // Simulate processing delay
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _step = _PayStep.success);
      _animController.forward();

      // Auto close after showing success
      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        final txnId =
            'TXN${DateTime.now().millisecondsSinceEpoch}GPAY';
        widget.onSuccess(txnId);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _step == _PayStep.success
            ? _buildSuccess()
            : _step == _PayStep.processing
                ? _buildProcessing()
                : _buildEnterUpi(),
      ),
    );
  }

  Widget _buildEnterUpi() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Google Pay logo header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildGPayLogo(),
              const SizedBox(width: 8),
              const Text(
                'Google Pay',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Amount chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
            ),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            '₹ ${widget.amount.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Paying ${widget.recipientName}',
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          widget.description,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: Colors.black54),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 20),
        // UPI field
        TextField(
          controller: _upiController,
          decoration: InputDecoration(
            labelText: 'UPI ID',
            hintText: 'yourname@okaxis',
            prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
            errorText: _upiError,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: widget.onCancel,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _onPay,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Pay Now',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProcessing() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildGPayLogo(),
        const SizedBox(height: 20),
        const CircularProgressIndicator(color: Color(0xFF1976D2)),
        const SizedBox(height: 16),
        const Text(
          'Processing Payment...',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Text(
          'Please wait',
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: _scaleAnim,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF4CAF50),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 48),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Payment Successful!',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF4CAF50),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '₹ ${widget.amount.toStringAsFixed(2)} paid to ${widget.recipientName}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildGPayLogo(size: 18),
            const SizedBox(width: 4),
            const Text(
              'via Google Pay',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGPayLogo({double size = 28}) {
    // Draw the G-Pay logo using colored letters
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('G',
            style: TextStyle(
                fontSize: size,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF4285F4))),
        Text('P',
            style: TextStyle(
                fontSize: size,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFEA4335))),
        Text('a',
            style: TextStyle(
                fontSize: size,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFFBBC05))),
        Text('y',
            style: TextStyle(
                fontSize: size,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF34A853))),
      ],
    );
  }
}

enum _PayStep { enter, processing, success }
