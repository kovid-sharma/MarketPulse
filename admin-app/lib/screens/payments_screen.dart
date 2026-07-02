import 'package:flutter/material.dart';

class PaymentsScreen extends StatelessWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0D1A),
        elevation: 0,
        title: const Text('Payments Overview',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Coming soon banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFF59E0B).withOpacity(0.15),
                    const Color(0xFFF97316).withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFFF59E0B).withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.construction_rounded,
                      color: Color(0xFFF59E0B), size: 22),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payments — Coming Soon',
                          style: TextStyle(
                            color: Color(0xFFF59E0B),
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'This screen shows mock data. Real payment processing '
                          'will be integrated in a future phase.',
                          style: TextStyle(
                              color: Color(0xFFB0B3C6), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Mock stats
            const Text('Revenue Summary (Mock)',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _MockStatCard(
                    label: 'MRR',
                    value: '₹2,48,000',
                    change: '+12.4%',
                    positive: true,
                    icon: Icons.currency_rupee_rounded,
                    color: const Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MockStatCard(
                    label: 'Active Subs',
                    value: '1,240',
                    change: '+84',
                    positive: true,
                    icon: Icons.people_rounded,
                    color: const Color(0xFF6366F1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MockStatCard(
                    label: 'Churn Rate',
                    value: '3.2%',
                    change: '-0.4%',
                    positive: true,
                    icon: Icons.trending_down_rounded,
                    color: const Color(0xFFF59E0B),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MockStatCard(
                    label: 'Trial Users',
                    value: '312',
                    change: '+28',
                    positive: true,
                    icon: Icons.hourglass_top_rounded,
                    color: const Color(0xFF0EA5E9),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Recent Transactions (Mock)',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ..._mockTransactions
                .map((t) => _MockTransactionTile(transaction: t)),
          ],
        ),
      ),
    );
  }
}

final _mockTransactions = [
  {'user': 'user_***@gmail.com', 'plan': 'Pro Monthly', 'amount': '₹999', 'status': 'paid', 'date': '02 Jul 2026'},
  {'user': 'trader_***@yahoo.com', 'plan': 'Pro Monthly', 'amount': '₹999', 'status': 'paid', 'date': '01 Jul 2026'},
  {'user': 'invest_***@hotmail.com', 'plan': 'Basic Yearly', 'amount': '₹4,999', 'status': 'paid', 'date': '30 Jun 2026'},
  {'user': 'fin_***@outlook.com', 'plan': 'Pro Monthly', 'amount': '₹999', 'status': 'failed', 'date': '29 Jun 2026'},
  {'user': 'market_***@gmail.com', 'plan': 'Basic Monthly', 'amount': '₹499', 'status': 'paid', 'date': '28 Jun 2026'},
];

class _MockStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String change;
  final bool positive;
  final IconData icon;
  final Color color;

  const _MockStatCard({
    required this.label,
    required this.value,
    required this.change,
    required this.positive,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2D3E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 10),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Color(0xFF8B8FA8), fontSize: 12)),
              const Spacer(),
              Text(change,
                  style: TextStyle(
                      color: positive
                          ? const Color(0xFF00C851)
                          : const Color(0xFFEF4444),
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MockTransactionTile extends StatelessWidget {
  final Map<String, String> transaction;
  const _MockTransactionTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isPaid = transaction['status'] == 'paid';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2D3E)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (isPaid ? const Color(0xFF00C851) : const Color(0xFFEF4444))
                  .withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isPaid ? Icons.check_rounded : Icons.close_rounded,
              color: isPaid ? const Color(0xFF00C851) : const Color(0xFFEF4444),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(transaction['user']!,
                    style: const TextStyle(color: Colors.white, fontSize: 13)),
                Text(transaction['plan']!,
                    style: const TextStyle(
                        color: Color(0xFF6B7280), fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(transaction['amount']!,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
              Text(transaction['date']!,
                  style: const TextStyle(
                      color: Color(0xFF6B7280), fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}
