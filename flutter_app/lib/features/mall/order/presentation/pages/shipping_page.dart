import 'package:flutter/material.dart';

import '../../../shared/mall_widgets.dart';
import '../../domain/order_models.dart';

class ShippingPage extends StatefulWidget {
  const ShippingPage({
    super.key,
    required this.order,
    required this.gateway,
    this.updateOnly = false,
  });

  final ShopOrder order;
  final SecondHandOrderGateway gateway;
  final bool updateOnly;

  @override
  State<ShippingPage> createState() => _ShippingPageState();
}

class _ShippingPageState extends State<ShippingPage> {
  late final TextEditingController _trackingController;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _trackingController = TextEditingController(
      text: widget.order.trackingNumber ?? '',
    );
  }

  @override
  void dispose() {
    _trackingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.order.items.firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.updateOnly ? '补充物流单号' : '确认发货'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (item != null)
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: MallNetworkImage(
                    url: item.productImage,
                    width: 68,
                    height: 68,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.productName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 24),
          Text(
            '${widget.order.receiverName ?? ''}  ${widget.order.receiverPhone ?? ''}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            widget.order.shippingAddress ?? '',
            style: const TextStyle(color: Color(0xFF667085)),
          ),
          const SizedBox(height: 28),
          TextField(
            key: const ValueKey('shipping-tracking-input'),
            controller: _trackingController,
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: '物流单号（选填）',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.all(16),
        child: FilledButton.icon(
          key: const ValueKey('confirm-shipping-button'),
          onPressed: _submitting ? null : _submit,
          icon: _submitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.local_shipping_outlined),
          label: Text(widget.updateOnly ? '保存物流单号' : '确认发货'),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final value = _trackingController.text.trim();
      if (widget.updateOnly) {
        await widget.gateway.updateTracking(
          widget.order.id,
          trackingNumber: value.isEmpty ? null : value,
        );
      } else {
        await widget.gateway.shipOrder(
          widget.order.id,
          trackingNumber: value.isEmpty ? null : value,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) showMallMessage(context, '$error', error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
