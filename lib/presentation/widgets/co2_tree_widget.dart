import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class Co2TreeWidget extends StatelessWidget {
  final double totalCo2Saved;

  const Co2TreeWidget({super.key, required this.totalCo2Saved});

  @override
  Widget build(BuildContext context) {
    // 1 Tree = ~25kg CO2 absorption/year
    double trees = totalCo2Saved / 25;
    double progress = trees - trees.floor();
    int totalTrees = trees.floor();
    int nextPercentage = (progress * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
      ),
      child: Column(
        children: [
          const Text("Global Green Impact", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Icon(FontAwesomeIcons.tree, size: 80, color: Colors.grey.shade200),
                  ClipRect(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      heightFactor: progress,
                      child: const Icon(FontAwesomeIcons.tree, size: 80, color: Colors.green),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 30),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("$nextPercentage%", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.green)),
                  Text("to next tree", style: TextStyle(color: Colors.grey.shade600)),
                  const SizedBox(height: 8),
                  Text("$totalTrees Trees Planted", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              )
            ],
          ),
          const SizedBox(height: 16),
          Text(
            "Users have saved as much CO₂ as $totalTrees mature trees absorb in a year!",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.green, fontSize: 12),
          ),
        ],
      ),
    );
  }
}