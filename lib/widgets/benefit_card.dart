import 'package:flutter/material.dart';

import '../api/models/benefit.dart';
import '../theme.dart';
import '../utils/formatters.dart';

/// Tarjeta de beneficio: texto a la izquierda, valor grande a la derecha.
class BenefitCard extends StatelessWidget {
  final Benefit benefit;

  const BenefitCard({super.key, required this.benefit});

  static const _line = TextStyle(
    fontSize: 14.5,
    fontWeight: FontWeight.w500,
    color: CelfixColors.blue,
    height: 1.3,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: CelfixShape.cardDecoration(color: CelfixColors.cardSoft),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(benefit.title, style: _line),
                if (benefit.description != null)
                  Text(benefit.description!, style: _line),
                if (benefit.minPurchase != null && benefit.minPurchase! > 0)
                  Text(
                    'Compra mínima ${Fmt.money(benefit.minPurchase!)}',
                    style: _line,
                  ),
                if (benefit.conditions != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      benefit.conditions!,
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: CelfixColors.inkSoft,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (benefit.displayValue != null) ...[
            const SizedBox(width: 14),
            // display_value ya viene formateado del backend ("$100", "50%");
            // no lo reconstruimos desde value/value_type.
            Text(
              benefit.displayValue!,
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w700,
                color: CelfixColors.blue,
                height: 1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
