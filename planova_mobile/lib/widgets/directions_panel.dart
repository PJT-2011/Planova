import 'package:flutter/material.dart';

class DirectionsPanel extends StatelessWidget {
  final List<String> directions;
  final VoidCallback? onClose;

  const DirectionsPanel({Key? key, required this.directions, this.onClose})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (directions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '🧭 Turn-by-Turn Directions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (onClose != null)
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 8),

          // Directions list
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.3,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: directions.length,
              itemBuilder: (context, index) {
                return _buildDirectionItem(
                  index,
                  directions[index],
                  index == 0,
                  index == directions.length - 1,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionItem(
    int index,
    String direction,
    bool isFirst,
    bool isLast,
  ) {
    IconData icon;
    Color iconColor;

    if (isFirst) {
      icon = Icons.radio_button_checked;
      iconColor = Colors.green;
    } else if (isLast) {
      icon = Icons.flag;
      iconColor = Colors.red;
    } else {
      icon = Icons.arrow_forward;
      iconColor = Colors.blue;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step number or icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: isFirst || isLast
                  ? Icon(icon, size: 16, color: iconColor)
                  : Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: iconColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),

          // Direction text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  direction,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isFirst || isLast
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                if (!isLast)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    height: 1,
                    color: Colors.grey[300],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
