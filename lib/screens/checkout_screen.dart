// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:provider/provider.dart';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';
// import '../config/config.dart';
// import '../providers/provider.dart';

// // === Constants ===
// const kConstCity = 'Agra';
// const kConstState = 'UP';
// const kConstPincode = '282005';

// // === UPI (replace with your merchant details) ===
// const kMerchantVpa = 'paytmqr6jkklj@ptys';
// const kMerchantName = 'FPS Store';

// // === API base ===
// const kApiBase = '${AppConfig.baseUrl}/me/orders/';

// // ====== TOKEN (SharedPreferences-based) ======
// Future<String?> _readAuthToken() async {
//   final prefs = await SharedPreferences.getInstance();
//   final token = prefs.getString('token');
//   return (token != null && token.trim().isNotEmpty) ? token : null;
// }

// enum PaymentMethod { cod, online }

// enum UpiMode { qr, upiId }

// class CheckoutScreen extends StatefulWidget {
//   const CheckoutScreen({super.key});

//   @override
//   State<CheckoutScreen> createState() => _CheckoutScreenState();
// }

// class _CheckoutScreenState extends State<CheckoutScreen> {
//   final _formKey = GlobalKey<FormState>();

//   // Dynamic profile fields (non-editable UI)
//   String _name = 'Customer';
//   String _phone = '';
//   String _addr1 = '';
//   String _addr2 = '';

//   PaymentMethod _method = PaymentMethod.cod;
//   UpiMode _upiMode = UpiMode.qr;
//   bool _loading = false;

//   @override
//   void initState() {
//     super.initState();
//     _loadProfileFromPrefs();
//   }

//   Future<void> _loadProfileFromPrefs() async {
//     final prefs = await SharedPreferences.getInstance();
//     final name = prefs.getString('name') ?? 'Customer';
//     final phone = prefs.getString('phone') ?? '';
//     final address = prefs.getString('address') ?? '';

//     // Best-effort split of address into two lines
//     String line1 = address, line2 = '';
//     final comma = address.indexOf(',');
//     if (comma > 0) {
//       line1 = address.substring(0, comma).trim();
//       line2 = address.substring(comma + 1).trim();
//     }

//     setState(() {
//       _name = name;
//       _phone = phone;
//       _addr1 = line1;
//       _addr2 = line2;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     final cart = context.watch<CartProvider>();
//     final lines = cart.lines.values.toList();

//     return Scaffold(
//       appBar: AppBar(title: const Text('Checkout')),
//       body: lines.isEmpty
//           ? const Center(child: Text('Your cart is empty'))
//           : SingleChildScrollView(
//               padding: const EdgeInsets.all(16),
//               child: Form(
//                 key: _formKey,
//                 child: Column(
//                   children: [
//                     // ===== Shipping Details (single, non-editable card) =====
//                     _Section(
//                       title: 'Shipping Details',
//                       child: _shippingSummaryCard(),
//                     ),

//                     const SizedBox(height: 16),

//                     // ===== Payment Info Note =====
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Payment will be requested after admin confirmation.',
                              style: TextStyle(color: Colors.blue),
                            ),
                          ),
                        ],
                      ),
                    ),

//                     const SizedBox(height: 16),

//                     // ===== Order Summary =====
//                     _Section(
//                       title: 'Order Summary',
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.stretch,
//                         children: [
//                           for (final l in lines)
//                             ListTile(
//                               dense: true,
//                               contentPadding: EdgeInsets.zero,
//                               title: Text(l.title),
//                               trailing: Text(
//                                 'x${l.qty}  ₹${(l.price * l.qty).toStringAsFixed(2)}',
//                               ),
//                             ),
//                           const Divider(),
//                           Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                             children: [
//                               const Text(
//                                 'Total',
//                                 style: TextStyle(fontWeight: FontWeight.w700),
//                               ),
//                               Text(
//                                 '₹ ${cart.total.toStringAsFixed(2)}',
//                                 style: const TextStyle(
//                                   fontWeight: FontWeight.w700,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ],
//                       ),
//                     ),

//                     const SizedBox(height: 24),

//                     // ===== Place Order =====
//                     SizedBox(
//                       width: double.infinity,
//                       child: FilledButton(
//                         onPressed: _loading ? null : _onMakePayment,
//                         child: _loading
//                             ? const SizedBox(
//                                 height: 20,
//                                 width: 20,
//                                 child: CircularProgressIndicator(
//                                   strokeWidth: 2,
//                                 ),
//                               )
//                             : const Text('Place Your Order'),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//     );
//   }

//   // Single, non-editable summary card for user details
//   Widget _shippingSummaryCard() {
//     final addrFull = [
//       if (_addr1.isNotEmpty) _addr1,
//       if (_addr2.isNotEmpty) _addr2,
//       '$kConstCity, $kConstState - $kConstPincode',
//     ].join('\n');

//     return Container(
//       decoration: BoxDecoration(
//         color: Theme.of(context).cardColor,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: Colors.grey.shade300),
//       ),
//       padding: const EdgeInsets.all(12),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Icon(Icons.location_on_outlined),
//           const SizedBox(width: 10),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 // Name + Phone
//                 Row(
//                   children: [
//                     Expanded(
//                       child: Text(
//                         _name.isEmpty ? 'Customer' : _name,
//                         style: const TextStyle(
//                           fontWeight: FontWeight.w700,
//                           fontSize: 16,
//                         ),
//                       ),
//                     ),
//                     Text(
//                       _phone.isEmpty ? '' : '+91 $_phone',
//                       style: TextStyle(color: Colors.grey.shade700),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 6),
//                 // Address lines + city/state/pincode
//                 Text(addrFull, style: const TextStyle(height: 1.3)),
//               ],
//             ),
//           ),
//     if (token == null || token.isEmpty) {
//       throw Exception('Not authenticated. Please log in again.');
//     }
//     return {
//       'Content-Type': 'application/json',
//       'Accept': 'application/json',
//       'Authorization': 'Token $token',
//     };
//   }

//   String? _extractErrorMessage(String body) {
//     try {
//       final parsed = jsonDecode(body);
//       if (parsed is Map) {
//         if (parsed['detail'] != null) return parsed['detail'].toString();
//         if (parsed['error'] != null) return parsed['error'].toString();
//         if (parsed.values.isNotEmpty) return parsed.values.first.toString();
//       }
//     } catch (_) {}
//     return null;
//   }

//   Future<bool> _createOrder(Map<String, dynamic> payload) async {
//     try {
//       final headers = await _authJsonHeaders();
//       final res = await http.post(
//         Uri.parse(kApiBase),
//         headers: headers,
//         body: jsonEncode(payload),
//       );
//       if (res.statusCode == 200 || res.statusCode == 201) return true;

//       debugPrint('Create COD order failed: ${res.statusCode} ${res.body}');
//       final msg = _extractErrorMessage(res.body) ?? 'HTTP ${res.statusCode}';
//       if (mounted) {
//         ScaffoldMessenger.of(
//           context,
//         ).showSnackBar(SnackBar(content: Text('Create order failed: $msg')));
//       }
//       return false;
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(
//           context,
//         ).showSnackBar(SnackBar(content: Text('Auth/Network error: $e')));
//       }
//       return false;
//     }
//   }

//   Future<_OrderCreateRes?> _createOrderAndGetId(
//     Map<String, dynamic> payload,
//   ) async {
//     try {
//       final headers = await _authJsonHeaders();
//       final res = await http.post(
//         Uri.parse(kApiBase),
//         headers: headers,
//         body: jsonEncode(payload),
//       );
//       if (res.statusCode != 200 && res.statusCode != 201) {
//         debugPrint('Create UPI order failed: ${res.statusCode} ${res.body}');
//         final msg = _extractErrorMessage(res.body);
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text(
//                 'Create UPI order failed: ${msg ?? res.statusCode}',
//               ),
//             ),
//           );
//         }
//         return null;
//       }
//       final data = jsonDecode(res.body);
//       final id = data['id'] ?? data['order_id'];
//       final amount = (data['total_amount'] ?? data['amount'] ?? 0).toDouble();
//       return _OrderCreateRes(
//         orderId: id is int ? id : int.tryParse(id.toString()) ?? 0,
//         amount: amount,
//       );
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(
//           context,
//         ).showSnackBar(SnackBar(content: Text('Auth/Network error: $e')));
//       }
//       return null;
//     }
//   }
// }

// class _OrderCreateRes {
//   final int orderId;
//   final double amount;
//   _OrderCreateRes({required this.orderId, required this.amount});
// }

// class _Section extends StatelessWidget {
//   final String title;
//   final Widget child;
//   const _Section({required this.title, required this.child});

//   @override
//   Widget build(BuildContext context) {
//     return Card(
//       elevation: 0.5,
//       child: Padding(
//         padding: const EdgeInsets.all(12),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             Text(
//               title,
//               style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
//             ),
//             const SizedBox(height: 8),
//             child,
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _LabeledRow extends StatelessWidget {
//   final String label;
//   final String value;
//   final bool copyable;
//   const _LabeledRow({
//     required this.label,
//     required this.value,
//     this.copyable = false,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       children: [
//         Expanded(child: Text('$label: $value')),
//         if (copyable)
//           IconButton(
//             icon: const Icon(Icons.copy),
//             onPressed: () async {
//               await Clipboard.setData(ClipboardData(text: value));
//               if (context.mounted) {
//                 ScaffoldMessenger.of(
//                   context,
//                 ).showSnackBar(const SnackBar(content: Text('Copied')));
//               }
//             },
//           ),
//       ],
//     );
//   }
// }
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/config.dart';
import '../providers/provider.dart';

// === Constants ===
const kConstCity = 'Agra';
const kConstState = 'UP';
const kConstPincode = '282005';

// === UPI (replace with your merchant details) ===
const kMerchantVpa = 'paytmqr6jkklj@ptys';
const kMerchantName = 'FPS Store';

// === API base ===
const kApiBase = '${AppConfig.baseUrl}/me/orders/';

// ====== TOKEN (SharedPreferences-based) ======
Future<String?> _readAuthToken() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  return (token != null && token.trim().isNotEmpty) ? token : null;
}

enum UpiMode { qr, upiId }

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();

  // Dynamic profile fields (non-editable UI)
  String _name = 'Customer';
  String _phone = '';
  String _addr1 = '';
  String _addr2 = '';

  UpiMode _upiMode = UpiMode.qr;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadProfileFromPrefs();
  }

  Future<void> _loadProfileFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('name') ?? 'Customer';
    final phone = prefs.getString('phone') ?? '';
    final address = prefs.getString('address') ?? '';

    // Best-effort split of address into two lines
    String line1 = address, line2 = '';
    final comma = address.indexOf(',');
    if (comma > 0) {
      line1 = address.substring(0, comma).trim();
      line2 = address.substring(comma + 1).trim();
    }

    setState(() {
      _name = name;
      _phone = phone;
      _addr1 = line1;
      _addr2 = line2;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final lines = cart.lines.values.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: lines.isEmpty
          ? const Center(child: Text('Your cart is empty'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // ===== Shipping Details (single, non-editable card) =====
                    _Section(
                      title: 'Shipping Details',
                      child: _shippingSummaryCard(),
                    ),

                    const SizedBox(height: 16),

                    // ===== Payment Info Note =====
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Payment will be requested after admin confirmation.',
                              style: TextStyle(color: Colors.blue),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ===== Order Summary =====
                    _Section(
                      title: 'Order Summary',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final l in lines)
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(l.title),
                              trailing: Text(
                                'x${l.qty}',
                              ),
                            ),
                          const Divider(),
                          // Hide total price here too
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                'TBD',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ===== Place Order =====
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _loading ? null : _onRequestOrder,
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Request Order'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // Single, non-editable summary card for user details
  Widget _shippingSummaryCard() {
    final addrFull = [
      if (_addr1.isNotEmpty) _addr1,
      if (_addr2.isNotEmpty) _addr2,
      '$kConstCity, $kConstState - $kConstPincode',
    ].join('\n');

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.location_on_outlined),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + Phone
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _name.isEmpty ? 'Customer' : _name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Text(
                      _phone.isEmpty ? '' : '+91 $_phone',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Address lines + city/state/pincode
                Text(addrFull, style: const TextStyle(height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Payment options removed: Payment is post-confirmation.

  Future<void> _onRequestOrder() async {
    // Manual sanity checks (no editable fields)
    if ((_name.trim().isEmpty) ||
        (_phone.trim().length < 10) ||
        (_addr1.trim().isEmpty)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Missing profile details. Please add name/phone/address in your account.',
          ),
        ),
      );
      return;
    }

    final cart = context.read<CartProvider>();
    if (cart.lines.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cart is empty')));
      return;
    }

    setState(() => _loading = true);

    try {
      final payload = _buildOrderPayload(
        paymentMethod: 'COD', // Default to COD/Request for now
        name: _name.trim(),
        phone: _phone.trim(),
        addr1: _addr1.trim(),
        addr2: _addr2.trim(),
        city: kConstCity,
        state: kConstState,
        pincode: kConstPincode,
        cart: cart,
      );

      final ok = await _createOrder(payload);
      if (!ok) throw Exception('Failed to place order request.');
      if (!mounted) return;
      cart.clear(); // Clear cart after successful request
      
      await showDialog(
        context: context, 
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text("Order Requested"),
          content: const Text("Your order has been placed. Please wait for admin confirmation regarding price and availability."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx); // Close dialog
                Navigator.pop(context); // Close checkout
              }, 
              child: const Text("OK")
            )
          ],
        )
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // --- Helpers ---

  Map<String, dynamic> _buildOrderPayload({
    required String paymentMethod,
    required String name,
    required String phone,
    required String addr1,
    required String addr2,
    required String city,
    required String state,
    required String pincode,
    required CartProvider cart,
  }) {
    final items = cart.lines.values
        .map((l) => {'product_id': l.productId, 'quantity': l.qty})
        .toList();

    return {
      'payment_method': paymentMethod, // 'ONLINE'
      'shipping_name': name,
      'shipping_phone': phone,
      'address_line1': addr1,
      'address_line2': addr2,
      'city': city,
      'state': state,
      'pincode': pincode,
      'items': items,
    };
  }

  // ---------- Networking helpers ----------
  Future<Map<String, String>> _authJsonHeaders() async {
    final token = await _readAuthToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated. Please log in again.');
    }
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Token $token',
    };
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

  Future<bool> _createOrder(Map<String, dynamic> payload) async {
    try {
      final headers = await _authJsonHeaders();
      final res = await http.post(
        Uri.parse(kApiBase),
        headers: headers,
        body: jsonEncode(payload),
      );
      if (res.statusCode == 200 || res.statusCode == 201) return true;

      debugPrint('Create order failed: ${res.statusCode} ${res.body}');
      final msg = _extractErrorMessage(res.body) ?? 'HTTP ${res.statusCode}';
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Create order failed: $msg')));
      }
      return false;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Auth/Network error: $e')));
      }
      return false;
    }
  }

  Future<_OrderCreateRes?> _createOrderAndGetId(
    Map<String, dynamic> payload,
  ) async {
    try {
      final headers = await _authJsonHeaders();
      final res = await http.post(
        Uri.parse(kApiBase),
        headers: headers,
        body: jsonEncode(payload),
      );
      if (res.statusCode != 200 && res.statusCode != 201) {
        debugPrint('Create online order failed: ${res.statusCode} ${res.body}');
        final msg = _extractErrorMessage(res.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Create order failed: ${msg ?? res.statusCode}',
              ),
            ),
          );
        }
        return null;
      }
      final data = jsonDecode(res.body);
      final id = data['id'] ?? data['order_id'];
      final amount = (data['total_amount'] ?? data['amount'] ?? 0).toDouble();
      return _OrderCreateRes(
        orderId: id is int ? id : int.tryParse(id.toString()) ?? 0,
        amount: amount,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Auth/Network error: $e')));
      }
      return null;
    }
  }
}

class _OrderCreateRes {
  final int orderId;
  final double amount;
  _OrderCreateRes({required this.orderId, required this.amount});
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0.5,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _LabeledRow extends StatelessWidget {
  final String label;
  final String value;
  final bool copyable;
  const _LabeledRow({
    required this.label,
    required this.value,
    this.copyable = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text('$label: $value')),
        if (copyable)
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: value));
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Copied')));
              }
            },
          ),
      ],
    );
  }
}
