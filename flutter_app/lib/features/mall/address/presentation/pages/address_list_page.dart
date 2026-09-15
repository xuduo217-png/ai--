import 'package:flutter/material.dart';

import '../../../shared/mall_widgets.dart';
import '../../domain/address_models.dart';
import '../address_controller.dart';
import 'address_edit_page.dart';

const _addressHeaderBackgroundColor = Color(0xFFDEE9FF);

class AddressListPage extends StatefulWidget {
  const AddressListPage({
    super.key,
    required this.gateway,
    this.selectionMode = false,
  });

  final AddressGateway gateway;
  final bool selectionMode;

  @override
  State<AddressListPage> createState() => _AddressListPageState();
}

class _AddressListPageState extends State<AddressListPage> {
  late final AddressController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AddressController(widget.gateway)..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Scaffold(
        backgroundColor: mallBackground,
        appBar: AppBar(
          backgroundColor: _addressHeaderBackgroundColor,
          surfaceTintColor: _addressHeaderBackgroundColor,
          title: Text(
            widget.selectionMode ? '选择收货地址' : '收货地址',
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
        ),
        body: _body(),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: FilledButton.icon(
              onPressed: () => _edit(),
              icon: const Icon(Icons.add),
              label: const Text('新增收货地址'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_controller.loading && _controller.addresses.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_controller.errorMessage != null && _controller.addresses.isEmpty) {
      return MallStateView(
        icon: Icons.wifi_off_outlined,
        message: _controller.errorMessage!,
        onRetry: _controller.load,
      );
    }
    if (_controller.addresses.isEmpty) {
      return const MallStateView(
        icon: Icons.location_off_outlined,
        message: '还没有收货地址',
      );
    }
    return RefreshIndicator(
      onRefresh: _controller.load,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _controller.addresses.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) =>
            _addressCard(_controller.addresses[index]),
      ),
    );
  }

  Widget _addressCard(ShippingAddress address) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: widget.selectionMode
            ? () => Navigator.pop(context, address)
            : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.location_on_outlined, color: mallPrimary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      address.receiverName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(address.receiverPhone),
                        if (address.isDefault)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '默认',
                              style: TextStyle(
                                color: Color(0xFF2E7D32),
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      address.fullAddress,
                      style: const TextStyle(height: 1.4),
                    ),
                    if (!widget.selectionMode)
                      Wrap(
                        spacing: 6,
                        children: [
                          if (!address.isDefault)
                            TextButton(
                              onPressed: () => _setDefault(address),
                              child: const Text('设为默认'),
                            ),
                          TextButton.icon(
                            onPressed: () => _edit(address),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('编辑'),
                          ),
                          TextButton.icon(
                            onPressed: () => _remove(address),
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('删除'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              if (widget.selectionMode) const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _edit([ShippingAddress? address]) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            AddressEditPage(controller: _controller, existing: address),
      ),
    );
    await _controller.load();
  }

  Future<void> _setDefault(ShippingAddress address) async {
    try {
      await _controller.setDefault(address.id);
    } catch (error) {
      if (mounted) showMallMessage(context, '$error', error: true);
    }
  }

  Future<void> _remove(ShippingAddress address) async {
    final confirmed = await showMallConfirm(
      context,
      title: '删除地址',
      message: '确定删除这个收货地址吗？',
    );
    if (!confirmed) return;
    try {
      await _controller.remove(address.id);
    } catch (error) {
      if (mounted) showMallMessage(context, '$error', error: true);
    }
  }
}
