import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class OrderConfirmationScreen extends StatelessWidget {
  const OrderConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              const Text('Order confirmed!', style: AppTextStyles.heading1),
              const SizedBox(height: 40),
              // Check icon
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(color: AppColors.lightGreen, borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.check, color: Colors.green, size: 40),
              ),
              const SizedBox(height: 24),
              const Text('Thank you, Maria!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.dark)),
              const SizedBox(height: 8),
              const Text(
                'Your order has been placed.\nConfirmation email sent.',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 24),
              // Order number
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: const Text('#HRB-20260525-0042', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: 0.5)),
              ),
              const SizedBox(height: 16),
              // Status rows
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
                child: Column(children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Status', style: AppTextStyles.caption),
                      Row(children: [
                        const Text('Paid', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.green)),
                        const SizedBox(width: 4),
                        const Icon(Icons.check, size: 14, color: Colors.green),
                      ]),
                    ],
                  ),
                  const Divider(height: 16),
                  const InfoRow(label: 'Delivery', value: '2-3 business days'),
                ]),
              ),
              const SizedBox(height: 32),
              PrimaryButton(
                label: 'Continue shopping',
                onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                child: const Text('View order history', style: TextStyle(color: AppColors.dark, fontWeight: FontWeight.w600, decoration: TextDecoration.underline)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
