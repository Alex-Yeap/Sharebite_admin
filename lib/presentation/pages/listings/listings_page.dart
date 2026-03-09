import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../controllers/admin_controller.dart';
import '../../../core/admin_theme.dart';

class ListingsPage extends StatefulWidget {
  const ListingsPage({super.key});

  @override
  State<ListingsPage> createState() => _ListingsPageState();
}

class _ListingsPageState extends State<ListingsPage> {
  String _search = "";

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<AdminController>(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text("Food Listings", style: AdminTheme.headerStyle),
              const Spacer(),
              SizedBox(
                width: 300,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: "Search food...",
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: (val) => setState(() => _search = val.toLowerCase()),
                ),
              )
            ],
          ),
          const SizedBox(height: 24),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('listings').where('status', isEqualTo: 'available').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final title = (data['title'] ?? '').toString().toLowerCase();
                  final merchant = (data['merchantName'] ?? '').toString().toLowerCase();
                  return _search.isEmpty || title.contains(_search) || merchant.contains(_search);
                }).toList();

                if (docs.isEmpty) return const Center(child: Text("No listings found."));

                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 300,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 24,
                    mainAxisSpacing: 24,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    return _AdminListingCard(
                      data: data,
                      onDelete: () => _confirmDelete(context, docs[index].id, controller),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, String docId, AdminController controller) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Listing?"),
        content: const Text("This will permanently remove this item."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () { controller.deleteListing(docId); Navigator.pop(ctx); },
              child: const Text("Force Delete")
          ),
        ],
      ),
    );
  }
}

class _AdminListingCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onDelete;

  const _AdminListingCard({required this.data, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final image = data['imageUrl'];
    final title = data['title'] ?? 'Unknown';
    final merchant = data['merchantName'] ?? 'Merchant';
    final price = data['discountedPrice'] ?? 0;
    final Timestamp? endTs = data['pickupEndTime'];
    final String deadline = endTs != null ? DateFormat('MMM dd, hh:mm a').format(endTs.toDate()) : 'No Deadline';
    final bool isExpired = endTs != null && endTs.toDate().isBefore(DateTime.now());

    return Container(
      decoration: AdminTheme.cardDecoration.copyWith(
        border: isExpired ? Border.all(color: Colors.red.shade200, width: 2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    image: image != null ? DecorationImage(image: NetworkImage(image), fit: BoxFit.cover) : null,
                  ),
                  child: image == null ? const Icon(Icons.fastfood, color: Colors.grey, size: 40) : null,
                ),
                Positioned(
                  top: 8, right: 8,
                  child: CircleAvatar(
                    backgroundColor: Colors.white, radius: 16,
                    child: IconButton(padding: EdgeInsets.zero, icon: const Icon(Icons.delete, color: Colors.red, size: 18), onPressed: onDelete),
                  ),
                ),
                if (isExpired)
                  Positioned(bottom: 0, left: 0, right: 0, child: Container(color: Colors.red.withOpacity(0.8), padding: const EdgeInsets.symmetric(vertical: 4), child: const Text("EXPIRED", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)))),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(children: [const Icon(FontAwesomeIcons.store, size: 12, color: Colors.grey), const SizedBox(width: 4), Expanded(child: Text(merchant, style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis))]),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text("RM $price", style: TextStyle(color: AdminTheme.studentGreen, fontWeight: FontWeight.bold)),
                  Row(children: [Icon(Icons.access_time, size: 12, color: isExpired ? Colors.red : Colors.grey), const SizedBox(width: 4), Text(deadline, style: TextStyle(fontSize: 10, color: isExpired ? Colors.red : Colors.grey, fontWeight: FontWeight.bold))]),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}