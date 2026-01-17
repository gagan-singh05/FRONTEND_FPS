import 'package:flutter/material.dart';
import '../theme/palette.dart';
import '../services/api_services.dart';
import '../models/product.dart';
import 'my_orders_page.dart';

class OrderDetailPage extends StatefulWidget {
  final MyOrder order;
  const OrderDetailPage({super.key, required this.order});

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  late MyOrder _order;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
  }

  Future<void> _updateQty(int itemId, int newQty) async {
    if (newQty < 1) return;
    final originalOrder = _order;
    setState(() {
      _isUpdating = true;
      _order = _order.copyWith(
        items: _order.items
            .map((it) => it.id == itemId ? it.copyWith(qty: newQty) : it)
            .toList(),
      );
    });
    try {
      final json = await ApiService.updateOrderQuantity(_order.id, itemId, newQty);
      await OrdersCache.clearPagination();
      if (mounted) {
        setState(() {
          _order = MyOrder.fromJson(json);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _order = originalOrder);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _removeItem(int itemId) async {
    final originalOrder = _order;
    setState(() {
      _isUpdating = true;
      _order = _order.copyWith(
        items: _order.items.where((it) => it.id != itemId).toList(),
      );
    });
    try {
      final json = await ApiService.removeItemFromOrder(_order.id, itemId);
      await OrdersCache.clearPagination();
      if (mounted) {
        setState(() {
          _order = MyOrder.fromJson(json);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _order = originalOrder);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _addItem() async {
    final Product? product = await showDialog<Product>(
      context: context,
      builder: (_) => const ProductSearchDialog(),
    );
    if (product == null) return;

    setState(() => _isUpdating = true);
    try {
      final json = await ApiService.addItemToOrder(_order.id, product.id, 1);
      await OrdersCache.clearPagination();
      if (mounted) {
        setState(() {
          _order = MyOrder.fromJson(json);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _cancelOrder() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cancel Order?"),
        content: const Text("Are you sure you want to cancel this order?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("No")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Yes, Cancel", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _isUpdating = true);
    try {
      final json = await ApiService.cancelOrder(_order.id);
      await OrdersCache.clearPagination();
      if (mounted) {
        setState(() {
          _order = MyOrder.fromJson(json);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Order cancelled successfully")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPending = _order.status.toUpperCase() == 'PENDING';
    final isConfirmed = _order.status.toUpperCase() == 'CONFIRMED';
    final isReady = _order.isReady;

    return Scaffold(
      backgroundColor: kBgBottom,
      appBar: AppBar(
        title: Text('Order #${_order.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_isUpdating)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Status Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: kPrimary,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
                   _statusIcon(_order.status),
                  const SizedBox(height: 12),
                  Text(
                    _order.statusDisplay.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                  ),
                  if (_order.createdAt != null)
                    Text(
                      'Placed on ${_order.createdAt!.toLocal().toString().split('.')[0]}',
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                    ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isReady) _infoBanner('Your order is ready — collect it within 30 mins.', kPrimarySoft, kPrimary),
                  if (isConfirmed) _infoBanner('Order Confirmed! Please pay to proceed.', Colors.blue.shade50, Colors.blue),

                  // Items Section
                  _sectionHeader('Items', trailing: isPending ? TextButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    label: const Text("Add More"),
                  ) : null),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: kBorder)),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _order.items.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: kBorder),
                      itemBuilder: (_, i) {
                        final it = _order.items[i];
                        return Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              // Product Image
                              Container(
                                width: 50, height: 50,
                                decoration: BoxDecoration(
                                  color: kBgBottom,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: kBorder),
                                ),
                                child: it.imageUrl != null 
                                  ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(it.imageUrl!, fit: BoxFit.cover))
                                  : Icon(Icons.shopping_bag_outlined, color: kPrimary.withOpacity(0.5)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(it.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                    if (!isPending) Text('₹${it.unitPrice} x ${it.qty}', style: TextStyle(color: kTextPrimary.withOpacity(0.6), fontSize: 13)),
                                  ],
                                ),
                              ),
                              if (isPending) ...[
                                Row(
                                  children: [
                                    _circleBtn(Icons.remove, () => _updateQty(it.id, it.qty - 1)),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      child: Text('${it.qty}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    ),
                                    _circleBtn(Icons.add, () => _updateQty(it.id, it.qty + 1)),
                                    const SizedBox(width: 8),
                                    _circleBtn(Icons.delete_outline, () => _removeItem(it.id), isDel: true),
                                  ],
                                )
                              ] else ...[
                                Text('₹${it.lineTotal.toStringAsFixed(1)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ]
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Order Summary
                  _sectionHeader('Order Summary'),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: kBorder)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _summaryRow('Total Amount', isPending ? 'TBD' : '₹${_order.totalAmount.toStringAsFixed(2)}', isBold: true),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Actions
                  if (isPending)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isUpdating ? null : _cancelOrder,
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text("CANCEL ORDER"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  
                  if (isConfirmed)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _showPaymentInfo(context, _order),
                        icon: const Icon(Icons.payment),
                        label: const Text("PROCEED TO PAY"),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusIcon(String status) {
    IconData icon;
    Color color = Colors.white;
    switch(status.toUpperCase()) {
      case 'PENDING': icon = Icons.timer_outlined; break;
      case 'CONFIRMED': icon = Icons.check_circle_outline; break;
      case 'READY': icon = Icons.shopping_bag_outlined; break;
      case 'DELIVERED': icon = Icons.home_outlined; break;
      default: icon = Icons.receipt_long;
    }
    return Icon(icon, color: color, size: 64);
  }

  Widget _infoBanner(String text, Color bg, Color textCol) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: textCol.withOpacity(0.2))),
    child: Row(
      children: [
        Icon(Icons.info_rounded, color: textCol, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: TextStyle(color: textCol, fontWeight: FontWeight.bold))),
      ],
    ),
  );

  Widget _sectionHeader(String title, {Widget? trailing}) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8, top: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kTextPrimary)),
        if (trailing != null) trailing,
      ],
    ),
  );

  Widget _summaryRow(String label, String value, {bool isBold = false}) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: TextStyle(color: kTextPrimary.withOpacity(0.6), fontSize: 15)),
      Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.w900 : FontWeight.w600, fontSize: isBold ? 18 : 15, color: kTextPrimary)),
    ],
  );

  Widget _circleBtn(IconData icon, VoidCallback? onTap, {bool isDel = false}) => Material(
    color: isDel ? Colors.red.withOpacity(0.1) : kPrimary.withOpacity(0.1),
    shape: const CircleBorder(),
    child: InkWell(
      onTap: _isUpdating ? null : onTap,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: Icon(icon, size: 18, color: isDel ? Colors.red : kPrimary),
      ),
    ),
  );

  void _showPaymentInfo(BuildContext context, MyOrder order) {
     showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Make Payment", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text("Total Amount: ₹ ${order.totalAmount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 20),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/payment_qr.jpg',
                    width: 250,
                    height: 250,
                    fit: BoxFit.cover,
                    errorBuilder: (_,__,___) => const SizedBox(height: 250, child: Center(child: Text("QR Code not found"))),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text("Scan QR to pay", style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SelectableText("UPI ID: yespay.rsbsdbconsumer1@yesbankltd", style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text("Bank: THE RADHASOAMI URBAN COOP BANK LTD.", style: TextStyle(color: Colors.grey[700], fontSize: 12), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              const Text("After payment, the admin will verify and process your order.", textAlign: TextAlign.center,),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text("Done")))
            ],
          ),
        ),
      )
    );
  }
}
