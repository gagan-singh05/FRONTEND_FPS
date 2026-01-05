import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/config.dart';
import '../theme/palette.dart'; // ← palette

/// ====== CONFIG ======
Uri get _ordersListUri =>
    Uri.parse('${AppConfig.baseUrl}/me/orders/'); // GET list
Uri _orderDetailUri(int id) =>
    Uri.parse('${AppConfig.baseUrl}/me/orders/$id/'); // GET one
Uri _orderCancelUri(int id) =>
    Uri.parse('${AppConfig.baseUrl}/me/orders/$id/cancel/'); // POST cancel

Future<Map<String, String>> _authJsonHeaders({
  Map<String, String>? extra,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token'); // MUST be set at login
  return {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (token != null && token.isNotEmpty) 'Authorization': 'Token $token',
    if (extra != null) ...extra,
  };
}

/// ====== LIGHTWEIGHT CACHING (SharedPreferences) ======
class _OrdersCache {
  static const _kListBody = 'orders_list_body_v1';
  static const _kListEtag = 'orders_list_etag_v1';
  static const _kListAt = 'orders_list_at_v1';

  static String? _memListBody;
  static String? _memEtag;
  static DateTime? _memAt;

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _memListBody ??= p.getString(_kListBody);
    _memEtag ??= p.getString(_kListEtag);
    final atStr = p.getString(_kListAt);
    _memAt ??= atStr != null ? DateTime.tryParse(atStr) : null;
  }

  static Future<void> saveList(String body, String? etag) async {
    _memListBody = body;
    _memEtag = etag;
    _memAt = DateTime.now();
    final p = await SharedPreferences.getInstance();
    await p.setString(_kListBody, body);
    if (etag != null) await p.setString(_kListEtag, etag);
    await p.setString(_kListAt, _memAt!.toIso8601String());
  }

  static String? get body => _memListBody;
  static String? get etag => _memEtag;

  // Per-order detail cache
  static String _detailKey(int id) => 'order_detail_body_$id';
  static Future<void> saveDetail(int id, String body) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_detailKey(id), body);
  }

  static Future<String?> loadDetailBody(int id) async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_detailKey(id));
  }
}

/// ====== MODELS ======
class MyOrder {
  final int id;
  final String status; // PENDING, PAID, CANCELLED, RECEIVED, READY, DELIVERED, etc.
  final String statusDisplay; // "Pending"
  final String paymentMethod; // COD, UPI
  final double totalAmount;
  final DateTime? createdAt;
  final List<MyOrderLine> items;

  bool get canCancel => status.toUpperCase() == 'PENDING';

  // Convenience getters for status-based UI logic
  bool get isPending => status.toUpperCase() == 'PENDING';
  bool get isReceived => status.toUpperCase() == 'RECEIVED';
  bool get isReady => status.toUpperCase() == 'READY';
  bool get isDelivered => status.toUpperCase() == 'DELIVERED';

  MyOrder({
    required this.id,
    required this.status,
    required this.statusDisplay,
    required this.paymentMethod,
    required this.totalAmount,
    required this.items,
    required this.createdAt,
  });

  factory MyOrder.fromJson(Map<String, dynamic> j) {
    double _toDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    return MyOrder(
      id: j['id'] is int ? j['id'] as int : int.tryParse('${j['id']}') ?? 0,
      status: (j['status'] ?? '').toString(),
      statusDisplay: (j['status_display'] ?? j['status'] ?? '').toString(),
      paymentMethod: (j['payment_method'] ?? '').toString(),
      totalAmount: _toDouble(j['total_amount'] ?? j['amount']),
      createdAt: j['created_at'] != null
          ? DateTime.tryParse(j['created_at'].toString())
          : null,
      items: (j['items'] as List<dynamic>? ?? [])
          .map((x) => MyOrderLine.fromJson(x as Map<String, dynamic>))
          .toList(),
    );
  }

  MyOrder copyWith({String? status, String? statusDisplay}) => MyOrder(
        id: id,
        status: status ?? this.status,
        statusDisplay: statusDisplay ?? this.statusDisplay,
        paymentMethod: paymentMethod,
        totalAmount: totalAmount,
        items: items,
        createdAt: createdAt,
      );
}

class MyOrderLine {
  final int id;
  final int productId;
  final String name;
  final int qty;
  final double unitPrice;
  final double lineTotal;

  MyOrderLine({
    required this.id,
    required this.productId,
    required this.name,
    required this.qty,
    required this.unitPrice,
    required this.lineTotal,
  });

  factory MyOrderLine.fromJson(Map<String, dynamic> j) {
    double _d(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse('${v ?? 0}') ?? 0.0;
    return MyOrderLine(
      id: j['id'] is int ? j['id'] : int.tryParse('${j['id']}') ?? 0,
      productId: j['product_id'] is int
          ? j['product_id']
          : int.tryParse('${j['product_id']}') ?? 0,
      name: (j['product_name'] ?? j['name'] ?? 'Item').toString(),
      qty: j['quantity'] is int
          ? j['quantity']
          : int.tryParse('${j['quantity']}') ?? 0,
      unitPrice: _d(j['unit_price']),
      lineTotal: _d(j['line_total']),
    );
  }
}

/// Off-main-isolate JSON parsing
List<MyOrder> _parseOrdersList(String body) {
  final list = (jsonDecode(body) as List<dynamic>).cast<dynamic>();
  return list.map((e) => MyOrder.fromJson(e as Map<String, dynamic>)).toList();
}

MyOrder _parseOrderDetail(String body) {
  final j = jsonDecode(body) as Map<String, dynamic>;
  return MyOrder.fromJson(j);
}

/// ====== SCREEN ======
class MyOrdersPage extends StatefulWidget {
  const MyOrdersPage({super.key});

  @override
  State<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage> {
  bool _loading = true;
  String? _error;
  List<MyOrder> _orders = [];
  final Map<int, bool> _canceling = {}; // orderId -> in-flight
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // 1) Load cached list fast
    await _OrdersCache.load();
    final cached = _OrdersCache.body;
    if (cached != null) {
      final parsed = await compute(_parseOrdersList, cached);
      if (mounted) {
        setState(() {
          _orders = parsed;
          _loading = false; // show instantly from cache
        });
      }
    }
    // 2) Refresh from network in background
    unawaited(_fetchOrders(fromUser: false));
    _initialized = true;
  }

  Future<void> _fetchOrders({bool fromUser = true}) async {
    if (fromUser && mounted) {
      setState(() {
        _loading = _orders.isEmpty; // if we already have some, don't block UI
        _error = null;
      });
    }
    try {
      final extra = <String, String>{};
      if (_OrdersCache.etag != null) {
        extra['If-None-Match'] = _OrdersCache.etag!;
      }
      final headers = await _authJsonHeaders(extra: extra);
      final res = await http
          .get(_ordersListUri, headers: headers)
          .timeout(const Duration(seconds: 12));

      if (res.statusCode == 304) {
        // Up-to-date; nothing to do.
        if (mounted) {
          setState(() {
            _loading = false;
          });
        }
        return;
      }

      if (res.statusCode != 200) {
        if (mounted) {
          setState(() {
            _error = _extractErrorMessage(res.body) ??
                'HTTP ${res.statusCode}: Failed to load orders';
            _loading = false;
          });
        }
        return;
      }

      // Parse off main thread
      final parsed = await compute(_parseOrdersList, res.body);
      if (mounted) {
        setState(() {
          _orders = parsed;
          _loading = false;
        });
      }

      // Cache raw body + etag
      await _OrdersCache.saveList(res.body, res.headers['etag']);
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _error = 'Network timeout. Pull to refresh.';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _refresh() => _fetchOrders(fromUser: true);

  /// Show order quickly if we already have items (or cached detail).
  Future<void> _openOrder(int id) async {
    // 1) Try in-memory list (many APIs include items in list)
    final local = _orders.firstWhere(
      (o) => o.id == id,
      orElse: () => MyOrder(
        id: id,
        status: '',
        statusDisplay: '',
        paymentMethod: '',
        totalAmount: 0,
        items: const [],
        createdAt: null,
      ),
    );
    if (local.items.isNotEmpty && local.status.isNotEmpty) {
      await showDialog(
        context: context,
        builder: (_) => _OrderDetailDialog(order: local),
      );
      // Optionally refresh detail silently
      unawaited(_prefetchOrderDetail(id));
      return;
    }

    // 2) Try cached detail from prefs
    final cachedBody = await _OrdersCache.loadDetailBody(id);
    if (cachedBody != null) {
      final cachedOrder = await compute(_parseOrderDetail, cachedBody);
      await showDialog(
        context: context,
        builder: (_) => _OrderDetailDialog(order: cachedOrder),
      );
      // Refresh silently
      unawaited(_prefetchOrderDetail(id));
      return;
    }

    // 3) Fallback to loader + network fetch
    final ord = await _withLoader<MyOrder?>(() async {
      try {
        final headers = await _authJsonHeaders();
        final res = await http
            .get(_orderDetailUri(id), headers: headers)
            .timeout(const Duration(seconds: 12));
        if (res.statusCode == 200) {
          final parsed = await compute(_parseOrderDetail, res.body);
          // cache detail
          unawaited(_OrdersCache.saveDetail(id, res.body));
          return parsed;
        } else {
          final msg = _extractErrorMessage(res.body) ??
              'HTTP ${res.statusCode}: Couldn\'t fetch order';
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(msg)));
          }
          return null;
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
        return null;
      }
    });

    if (!mounted || ord == null) return;
    await showDialog(
      context: context,
      builder: (_) => _OrderDetailDialog(order: ord),
    );
  }

  Future<void> _prefetchOrderDetail(int id) async {
    try {
      final headers = await _authJsonHeaders();
      final res = await http
          .get(_orderDetailUri(id), headers: headers)
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        unawaited(_OrdersCache.saveDetail(id, res.body));
      }
    } catch (_) {
      /* ignore */
    }
  }

  Future<T?> _withLoader<T>(Future<T> Function() task) async {
    if (!mounted) return null;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      return await task();
    } finally {
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _cancelOrder(MyOrder order) async {
    if (!order.canCancel) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel order?'),
        content: Text('Order #${order.id} will be cancelled.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() {
      _canceling[order.id] = true;
    });

    try {
      final headers = await _authJsonHeaders();
      final res = await http
          .post(_orderCancelUri(order.id), headers: headers)
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200 || res.statusCode == 202) {
        MyOrder updated = order;
        try {
          final body = jsonDecode(res.body);
          if (body is Map<String, dynamic>) {
            final status = (body['status'] ?? '').toString();
            final statusDisplay = (body['status_display'] ?? status).toString();
            if (status.isNotEmpty) {
              updated = order.copyWith(
                status: status,
                statusDisplay: statusDisplay,
              );
            }
          }
        } catch (_) {
          updated = order.copyWith(
            status: 'CANCELLED',
            statusDisplay: 'Cancelled',
          );
        }

        setState(() {
          _orders =
              _orders.map((o) => o.id == order.id ? updated : o).toList();
        });

        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Order cancelled')));
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _extractErrorMessage(res.body) ??
                  'HTTP ${res.statusCode}: Cancel failed',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _canceling.remove(order.id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('My Orders', style: TextStyle(color: kTextPrimary)),
        iconTheme: IconThemeData(color: kTextPrimary),
        backgroundColor: kBgTop,
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: Icon(Icons.refresh, color: kPrimary),
            tooltip: 'Refresh',
          ),
        ],
      ),
      backgroundColor: kBgBottom,
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(kPrimary),
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: kTextPrimary),
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: kPrimary,
                  onRefresh: _refresh,
                  child: _orders.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 120),
                            Center(
                              child: Text(
                                'No orders found',
                                style: TextStyle(color: kTextPrimary),
                              ),
                            ),
                            const SizedBox(height: 120),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemBuilder: (_, i) {
                            final o = _orders[i];
                            return _OrderTile(
                              order: o,
                              busy: _canceling[o.id] == true,
                              onOpen: () => _openOrder(o.id),
                              onCancel:
                                  o.canCancel ? () => _cancelOrder(o) : null,
                              colorScheme: scheme,
                            );
                          },
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemCount: _orders.length,
                        ),
                ),
    );
  }

  String? _extractErrorMessage(String body) {
    try {
      final parsed = jsonDecode(body);
      if (parsed is Map) {
        if (parsed['detail'] != null) return parsed['detail'].toString();
        if (parsed['error'] != null) return parsed['error'].toString();
        if (parsed.values.isNotEmpty) return parsed.values.first.toString();
      }
    } catch (_) {}
    return null;
  }
}

/// ====== WIDGETS ======
class _OrderTile extends StatelessWidget {
  final MyOrder order;
  final VoidCallback? onOpen;
  final VoidCallback? onCancel;
  final bool busy;
  final ColorScheme colorScheme;

  const _OrderTile({
    required this.order,
    this.onOpen,
    this.onCancel,
    this.busy = false,
    required this.colorScheme,
  });

  Color _statusColor(BuildContext context) {
    final s = order.status.toUpperCase();
    if (s == 'PENDING') return Colors.orange;
    if (s == 'RECEIVED') return Colors.green;
    if (s == 'CANCELLED') return Colors.red;
    if (s == 'DELIVERED') return Colors.blue;
    // READY or others
    return Theme.of(context).colorScheme.secondary;
  }

  String _dateStr(DateTime? dt) {
    if (dt == null) return '';
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final yyyy = dt.year.toString();
    return '$dd-$mm-$yyyy';
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(context);
    final dateStr = _dateStr(order.createdAt);
    final isReady = order.isReady; // ✅ Only true when status == READY

    return Card(
      color: kCard,
      elevation: 0.8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpen,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: statusColor.withOpacity(0.2)),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              // Top row: ID + Status chip + Amount
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          'Order #${order.id}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: kTextPrimary,
                          ),
                        ),
                        if (dateStr.isNotEmpty)
                          Text(
                            '• $dateStr',
                            style: TextStyle(
                              color: kTextPrimary.withOpacity(0.65),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Status chip
                  Container(
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.08),
                      border: Border.all(color: statusColor),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 8, color: statusColor),
                        const SizedBox(width: 6),
                        Text(
                          (order.statusDisplay.isNotEmpty
                                  ? order.statusDisplay
                                  : order.status)
                              .toString(),
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Middle: summary line
              Row(
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Items: ${order.items.length} • Pay: ${order.paymentMethod}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: kTextPrimary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '₹ ${order.totalAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: kTextPrimary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // If the order is marked ready, show a small notice to the user
              if (isReady)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: kPrimarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: kPrimary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your order is ready — collect it within 30 mins.',
                          style: TextStyle(
                            color: kTextPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Bottom: Cancel button (if allowed)
              if (onCancel != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    height: 32,
                    child: OutlinedButton.icon(
                      icon: busy
                          ? SizedBox(
                              height: 14,
                              width: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  kPrimary,
                                ),
                              ),
                            )
                          : Icon(
                              Icons.cancel_outlined,
                              size: 18,
                              color: kPrimary,
                            ),
                      label: Text(
                        busy ? 'Cancelling...' : 'Cancel',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: kPrimary,
                        ),
                      ),
                      onPressed: busy ? null : onCancel,
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        shape: const StadiumBorder(),
                        side: BorderSide(color: statusColor.withOpacity(0.7)),
                        backgroundColor: kPrimarySoft,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderDetailDialog extends StatelessWidget {
  final MyOrder order;
  const _OrderDetailDialog({required this.order});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isConfirmed = order.status.toUpperCase() == 'CONFIRMED';
    final isPending = order.status.toUpperCase() == 'PENDING';
    final isReady = order.isReady;

    return AlertDialog(
      backgroundColor: kBgBottom,
      title: Text(
        'Order Details',
        style: TextStyle(fontWeight: FontWeight.w800, color: kTextPrimary),
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _kv('Order #', '${order.id}'),
            const SizedBox(height: 6),
            _kv(
              'Status',
              order.statusDisplay.isNotEmpty
                  ? order.statusDisplay
                  : order.status,
            ),
            const SizedBox(height: 6),
            if (isReady)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: kPrimarySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: kPrimary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your order is ready — collect it within 30 mins.',
                        style: TextStyle(
                          color: kTextPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
            if (isConfirmed)
               Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                   border: Border.all(color: Colors.blue.shade100),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue),
                     SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Order Confirmed! Please pay to proceed.',
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            _kv('Payment', order.paymentMethod),
            const SizedBox(height: 6),
            if (isPending)
               _kv('Total', 'TBD (Waiting for Admin)')
            else
               _kv('Total', '₹ ${order.totalAmount.toStringAsFixed(2)}'),
            
            Divider(height: 16, color: kBorder),
            
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Items',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: cs.primary, 
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: ListView.separated(
                itemCount: order.items.length,
                itemBuilder: (_, i) {
                  final it = order.items[i];
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          it.name,
                          style: TextStyle(color: kTextPrimary),
                        ),
                      ),
                      Text('x${it.qty}',
                          style: TextStyle(color: kTextPrimary)),
                      const SizedBox(width: 8),
                      // Hide line item prices if pending, or show? 
                      // Spec says "without seeing prices", so hide in pending.
                      if (isPending) 
                         Text('Price TBD', style: TextStyle(color: kTextPrimary, fontSize: 12))
                      else
                        Text(
                          '₹ ${it.lineTotal.toStringAsFixed(2)}',
                          style: TextStyle(color: kTextPrimary),
                        ),
                    ],
                  );
                },
                separatorBuilder: (_, __) =>
                    Divider(height: 12, color: kBorder),
              ),
            ),
            
             if (isConfirmed) ...[
               const SizedBox(height: 16),
               SizedBox(
                 width: double.infinity,
                 child: FilledButton.icon(
                   onPressed: () {
                     Navigator.pop(context);
                     _showPaymentInfo(context, order);
                   },
                   icon: const Icon(Icons.payment),
                   label: const Text("Pay Now"),
                 ),
               )
             ]
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Close', style: TextStyle(color: kPrimary)),
        ),
      ],
    );
  }

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
              FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text("Done"))
            ],
          ),
        ),
      )
    );
  }

  Widget _kv(String k, String v) => Row(
        children: [
          Text(
            '$k: ',
            style: TextStyle(fontWeight: FontWeight.w700, color: kTextPrimary),
          ),
          Flexible(
            child: Text(v, style: TextStyle(color: kTextPrimary)),
          ),
        ],
      );
}
