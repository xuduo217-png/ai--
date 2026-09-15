import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pickers/pickers.dart';
import 'package:flutter_pickers/style/default_style.dart';

import '../../../../../core/media/gallery_media_picker.dart';
import '../../../shared/mall_widgets.dart';
import '../../domain/after_sale_models.dart';
import '../../domain/order_models.dart';
import '../widgets/after_sale_evidence_picker.dart';

class ApplyAfterSalePage extends StatefulWidget {
  const ApplyAfterSalePage({
    super.key,
    required this.order,
    required this.gateway,
    this.galleryMediaPicker,
  });

  final ShopOrder order;
  final AfterSaleGateway gateway;
  final GalleryMediaPicker? galleryMediaPicker;

  @override
  State<ApplyAfterSalePage> createState() => _ApplyAfterSalePageState();
}

class _ApplyAfterSalePageState extends State<ApplyAfterSalePage> {
  final _descriptionController = TextEditingController();
  late final GalleryMediaPicker _galleryMediaPicker;
  String _reason = 'product_issue';
  AfterSaleType _afterSaleType = AfterSaleType.refundOnly;
  final Map<String, int> _selectedQuantities = {};
  final List<String> _evidenceUrls = [];
  bool _submitting = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _galleryMediaPicker = widget.galleryMediaPicker ?? GalleryMediaPicker();
    for (final item in widget.order.items) {
      if (item.lineKey.isNotEmpty) {
        _selectedQuantities[item.lineKey] = item.quantity;
      }
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AfterSaleFormScaffold(
      title: '申请售后',
      submitting: _submitting,
      submitLabel: '提交售后申请',
      onSubmit: _submit,
      mallStyled: true,
      children: [
        _AfterSalePanel(
          key: const ValueKey('after-sale-type-section'),
          title: '售后类型',
          child: _AfterSaleTypeSelector(
            value: _afterSaleType,
            allowReturnRefund: _allowReturnRefund,
            onChanged: (value) => setState(() => _afterSaleType = value),
          ),
        ),
        const SizedBox(height: 12),
        _AfterSalePanel(
          key: const ValueKey('after-sale-items-section'),
          title: '售后商品',
          child: Column(
            children: [
              for (final (index, item) in widget.order.items.indexed) ...[
                _AfterSaleItemSelector(
                  item: item,
                  selectedQuantity: _selectedQuantities[item.lineKey] ?? 0,
                  onChanged: (quantity) => setState(() {
                    final lineKey = item.lineKey;
                    if (quantity <= 0) {
                      _selectedQuantities.remove(lineKey);
                    } else {
                      _selectedQuantities[lineKey] = quantity;
                    }
                  }),
                ),
                if (index < widget.order.items.length - 1)
                  const Divider(height: 25, color: Color(0xFFEFF1F5)),
              ],
              const Divider(height: 25, color: Color(0xFFEFF1F5)),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '预计可退 ¥${_selectedAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Color(0xFFE95656),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _AfterSalePanel(
          key: const ValueKey('after-sale-details-section'),
          title: '申请信息',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _AfterSaleFieldLabel('售后原因'),
              const SizedBox(height: 8),
              _AfterSaleReasonPicker(
                key: const ValueKey('after-sale-reason'),
                value: _reason,
                onChanged: (value) => setState(() => _reason = value),
              ),
              const SizedBox(height: 16),
              const _AfterSaleFieldLabel('详细说明'),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                minLines: 4,
                maxLines: 7,
                maxLength: 2000,
                decoration: const InputDecoration(
                  hintText: '请描述商品问题及您的处理期望',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _AfterSalePanel(
          key: const ValueKey('after-sale-evidence-section'),
          child: AfterSaleEvidencePicker(
            urls: _evidenceUrls,
            uploading: _uploading,
            onAdd: _pickEvidence,
            onRemove: (index) => setState(() => _evidenceUrls.removeAt(index)),
          ),
        ),
      ],
    );
  }

  bool get _allowReturnRefund => const {
    ShopOrderStatus.shipped,
    ShopOrderStatus.completed,
  }.contains(widget.order.status);

  double get _selectedAmount => widget.order.items.fold(0, (sum, item) {
    final quantity = _selectedQuantities[item.lineKey] ?? 0;
    if (quantity <= 0) return sum;
    return sum + item.actualPaidAmount * quantity / item.quantity;
  });

  Future<void> _pickEvidence() async {
    await _pickAndUploadEvidence(
      context: context,
      gateway: widget.gateway,
      galleryMediaPicker: _galleryMediaPicker,
      urls: _evidenceUrls,
      setUploading: (value) => setState(() => _uploading = value),
      refresh: () => setState(() {}),
    );
  }

  Future<void> _submit() async {
    if (_uploading) return;
    final items = widget.order.items
        .map(
          (item) => AfterSaleRequestItem(
            lineKey: item.lineKey,
            quantity: _selectedQuantities[item.lineKey] ?? 0,
          ),
        )
        .where((item) => item.lineKey.isNotEmpty && item.quantity > 0)
        .toList(growable: false);
    if (items.isEmpty) {
      showMallMessage(context, '请至少选择一件售后商品', error: true);
      return;
    }
    setState(() => _submitting = true);
    try {
      final result = await widget.gateway.createAfterSale(
        widget.order.id,
        afterSaleType: _afterSaleType,
        items: items,
        reasonCode: _reason,
        description: _descriptionController.text,
        evidenceUrls: _evidenceUrls,
      );
      if (mounted) Navigator.of(context).pop(result);
    } catch (error) {
      if (mounted) showMallMessage(context, '$error', error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class ReturnOrderPage extends StatefulWidget {
  const ReturnOrderPage({
    super.key,
    required this.afterSale,
    required this.gateway,
    this.galleryMediaPicker,
  });

  final OrderAfterSale afterSale;
  final AfterSaleGateway gateway;
  final GalleryMediaPicker? galleryMediaPicker;

  @override
  State<ReturnOrderPage> createState() => _ReturnOrderPageState();
}

class _ReturnOrderPageState extends State<ReturnOrderPage> {
  final _trackingController = TextEditingController();
  late final GalleryMediaPicker _galleryMediaPicker;
  final List<String> _evidenceUrls = [];
  bool _submitting = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _galleryMediaPicker = widget.galleryMediaPicker ?? GalleryMediaPicker();
  }

  @override
  void dispose() {
    _trackingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AfterSaleFormScaffold(
      title: '提交退货信息',
      submitting: _submitting,
      submitLabel: '确认提交',
      onSubmit: _submit,
      children: [
        if (widget.afterSale.returnAddress?.isNotEmpty == true) ...[
          const Text('退货地址', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          SelectableText(widget.afterSale.returnAddress!),
          const SizedBox(height: 20),
        ],
        TextField(
          key: const ValueKey('return-tracking-input'),
          controller: _trackingController,
          maxLength: 100,
          decoration: const InputDecoration(
            labelText: '退货物流单号（选填）',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        AfterSaleEvidencePicker(
          urls: _evidenceUrls,
          uploading: _uploading,
          onAdd: _pickEvidence,
          onRemove: (index) => setState(() => _evidenceUrls.removeAt(index)),
        ),
      ],
    );
  }

  Future<void> _pickEvidence() async {
    await _pickAndUploadEvidence(
      context: context,
      gateway: widget.gateway,
      galleryMediaPicker: _galleryMediaPicker,
      urls: _evidenceUrls,
      setUploading: (value) => setState(() => _uploading = value),
      refresh: () => setState(() {}),
    );
  }

  Future<void> _submit() async {
    if (_uploading) return;
    setState(() => _submitting = true);
    try {
      final result = await widget.gateway.submitReturn(
        widget.afterSale.id,
        trackingNumber: _trackingController.text,
        evidenceUrls: _evidenceUrls,
      );
      if (mounted) Navigator.of(context).pop(result);
    } catch (error) {
      if (mounted) showMallMessage(context, '$error', error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class ArbitrationPage extends StatefulWidget {
  const ArbitrationPage({
    super.key,
    required this.afterSale,
    required this.gateway,
    this.galleryMediaPicker,
  });

  final OrderAfterSale afterSale;
  final AfterSaleGateway gateway;
  final GalleryMediaPicker? galleryMediaPicker;

  @override
  State<ArbitrationPage> createState() => _ArbitrationPageState();
}

class _ArbitrationPageState extends State<ArbitrationPage> {
  final _reasonController = TextEditingController();
  late final GalleryMediaPicker _galleryMediaPicker;
  final List<String> _evidenceUrls = [];
  bool _submitting = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _galleryMediaPicker = widget.galleryMediaPicker ?? GalleryMediaPicker();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AfterSaleFormScaffold(
      title: '申请平台仲裁',
      submitting: _submitting,
      submitLabel: '提交仲裁申请',
      onSubmit: _submit,
      children: [
        TextField(
          key: const ValueKey('arbitration-reason-input'),
          controller: _reasonController,
          minLines: 5,
          maxLines: 8,
          maxLength: 2000,
          decoration: const InputDecoration(
            labelText: '仲裁理由',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        AfterSaleEvidencePicker(
          urls: _evidenceUrls,
          uploading: _uploading,
          onAdd: _pickEvidence,
          onRemove: (index) => setState(() => _evidenceUrls.removeAt(index)),
        ),
      ],
    );
  }

  Future<void> _pickEvidence() async {
    await _pickAndUploadEvidence(
      context: context,
      gateway: widget.gateway,
      galleryMediaPicker: _galleryMediaPicker,
      urls: _evidenceUrls,
      setUploading: (value) => setState(() => _uploading = value),
      refresh: () => setState(() {}),
    );
  }

  Future<void> _submit() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      showMallMessage(context, '请填写仲裁理由', error: true);
      return;
    }
    if (_uploading) return;
    setState(() => _submitting = true);
    try {
      final result = await widget.gateway.applyArbitration(
        widget.afterSale.id,
        reason: reason,
        evidenceUrls: _evidenceUrls,
      );
      if (mounted) Navigator.of(context).pop(result);
    } catch (error) {
      if (mounted) showMallMessage(context, '$error', error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class SellerAfterSalePage extends StatefulWidget {
  const SellerAfterSalePage({
    super.key,
    required this.afterSale,
    required this.gateway,
  });

  final OrderAfterSale afterSale;
  final AfterSaleGateway gateway;

  @override
  State<SellerAfterSalePage> createState() => _SellerAfterSalePageState();
}

class _SellerAfterSalePageState extends State<SellerAfterSalePage> {
  final _reasonController = TextEditingController();
  final _addressController = TextEditingController();
  bool _returnRequired = false;
  bool _submitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('处理售后'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('买家原因：${widget.afterSale.reasonCode}'),
          if (widget.afterSale.description?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(widget.afterSale.description!),
          ],
          const SizedBox(height: 24),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('收到退货后退款'),
            value: _returnRequired,
            onChanged: widget.afterSale.order?.status == ShopOrderStatus.shipped
                ? (value) => setState(() => _returnRequired = value)
                : null,
          ),
          if (_returnRequired) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _addressController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '退货地址',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _reasonController,
            maxLines: 4,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: '处理说明',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _submitting ? null : _reject,
                child: const Text('拒绝申请'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _submitting ? null : _approve,
                child: const Text('同意申请'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approve() async {
    if (_returnRequired && _addressController.text.trim().isEmpty) {
      showMallMessage(context, '请填写退货地址', error: true);
      return;
    }
    await _run(
      () => widget.gateway.approveAfterSale(
        widget.afterSale.id,
        returnRequired: _returnRequired,
        returnAddress: _addressController.text,
        reason: _reasonController.text,
      ),
    );
  }

  Future<void> _reject() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      showMallMessage(context, '拒绝时必须填写处理说明', error: true);
      return;
    }
    await _run(
      () => widget.gateway.rejectAfterSale(widget.afterSale.id, reason: reason),
    );
  }

  Future<void> _run(Future<OrderAfterSale> Function() action) async {
    setState(() => _submitting = true);
    try {
      final result = await action();
      if (mounted) Navigator.of(context).pop(result);
    } catch (error) {
      if (mounted) showMallMessage(context, '$error', error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class AfterSaleDetailPage extends StatefulWidget {
  const AfterSaleDetailPage({
    super.key,
    required this.afterSaleId,
    required this.gateway,
  });

  final int afterSaleId;
  final AfterSaleGateway gateway;

  @override
  State<AfterSaleDetailPage> createState() => _AfterSaleDetailPageState();
}

class _AfterSaleDetailPageState extends State<AfterSaleDetailPage> {
  OrderAfterSale? _afterSale;
  Object? _error;
  bool _loading = true;
  bool _acting = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFDEE9FF), Color(0xFFFAFBFF)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          toolbarHeight: 58,
          centerTitle: true,
          title: const Text(
            '售后详情',
            style: TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: _body(),
        bottomNavigationBar: _afterSale == null ? null : _actions(_afterSale!),
      ),
    );
  }

  Widget _body() {
    if (_loading && _afterSale == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null || _afterSale == null) {
      return MallStateView(
        icon: Icons.support_agent_outlined,
        message: '售后记录不存在或无权访问',
        onRetry: _load,
      );
    }
    final value = _afterSale!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 2, bottom: 24),
        children: [
          _statusCard(value),
          if (value.order case final order?)
            _section(
              '关联订单',
              Column(
                children: [
                  _infoRow('订单编号', order.orderNo),
                  _infoRow('订单状态', order.status.label),
                  _infoRow(
                    '订单金额',
                    '¥${order.totalAmount.toStringAsFixed(2)}',
                    valueColor: const Color(0xFFE95656),
                    strong: true,
                  ),
                ],
              ),
              icon: Icons.receipt_long_outlined,
            ),
          _section(
            '售后申请',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow('售后编号', value.afterSaleNo),
                _infoRow('售后类型', value.afterSaleType.label),
                _infoRow('处理方式', value.handlerType.label),
                _infoRow('申请原因', _afterSaleReasonLabel(value.reasonCode)),
                _infoRow(
                  value.approvedAmount == null ? '申请金额' : '审批退款金额',
                  '¥${value.refundAmount.toStringAsFixed(2)}',
                  valueColor: const Color(0xFFE95656),
                  strong: true,
                ),
                if (value.description?.isNotEmpty == true)
                  _description('问题说明', value.description!),
                if (value.evidenceUrls.isNotEmpty)
                  _evidence('申请凭证', value.evidenceUrls),
              ],
            ),
            icon: Icons.assignment_outlined,
          ),
          if (value.items.isNotEmpty)
            _section(
              '商品明细',
              Column(
                children: [
                  for (final item in value.items) _afterSaleItem(item),
                ],
              ),
              icon: Icons.inventory_2_outlined,
            ),
          if (_hasSellerSection(value))
            _section(
              value.handlerType.label,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (value.sellerDecision?.isNotEmpty == true)
                    _infoRow(
                      '处理结果',
                      _handlerDecisionLabel(
                        value.sellerDecision!,
                        value.handlerType,
                      ),
                    ),
                  if (value.sellerDecision == 'approved')
                    _infoRow(
                      '退款方式',
                      value.returnRequired == true ? '退货后退款' : '直接退款',
                    ),
                  if (value.sellerReason?.isNotEmpty == true)
                    _description(
                      value.handlerType == AfterSaleHandlerType.platform
                          ? '平台说明'
                          : '卖家说明',
                      value.sellerReason!,
                    ),
                  if (value.returnAddress?.isNotEmpty == true)
                    _description('退货地址', value.returnAddress!),
                ],
              ),
              icon: Icons.storefront_outlined,
            ),
          if (_hasReturnSection(value))
            _section(
              '退货信息',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (value.returnTrackingNumber?.isNotEmpty == true)
                    _trackingLine('退货物流单号', value.returnTrackingNumber!),
                  if (value.returnEvidenceUrls.isNotEmpty)
                    _evidence('退货凭证', value.returnEvidenceUrls),
                ],
              ),
              icon: Icons.local_shipping_outlined,
            ),
          if (_hasArbitrationSection(value))
            _section(
              '平台仲裁',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (value.arbitrationReason?.isNotEmpty == true)
                    _description('仲裁理由', value.arbitrationReason!),
                  if (value.arbitrationDecision?.isNotEmpty == true)
                    _infoRow(
                      '仲裁结果',
                      _arbitrationDecisionLabel(value.arbitrationDecision!),
                      valueColor: value.arbitrationDecision == 'support_buyer'
                          ? const Color(0xFF079455)
                          : const Color(0xFFB54708),
                      strong: true,
                    ),
                  if (value.arbitrationRemark?.isNotEmpty == true)
                    _description('平台说明', value.arbitrationRemark!),
                  if (value.arbitrationEvidenceUrls.isNotEmpty)
                    _evidence('仲裁凭证', value.arbitrationEvidenceUrls),
                ],
              ),
              icon: Icons.gavel_outlined,
            ),
          if (value.refundFailureReason?.isNotEmpty == true)
            _section(
              '退款信息',
              _notice(
                value.refundFailureReason!,
                icon: Icons.error_outline_rounded,
                color: const Color(0xFFD92D20),
              ),
              icon: Icons.payments_outlined,
            ),
          _section(
            '处理记录',
            value.logs.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '暂无处理记录',
                      style: TextStyle(color: Color(0xFF98A2B3)),
                    ),
                  )
                : Column(
                    children: [
                      for (var index = 0; index < value.logs.length; index++)
                        _timelineItem(
                          value.logs[index],
                          isLast: index == value.logs.length - 1,
                        ),
                    ],
                  ),
            icon: Icons.history_rounded,
          ),
        ],
      ),
    );
  }

  Widget _statusCard(OrderAfterSale value) {
    final color = _afterSaleStatusColor(value.status);
    return Container(
      key: ValueKey('after-sale-status-${value.status.wireValue}'),
      margin: const EdgeInsets.symmetric(horizontal: 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(height: 4, color: color),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
            child: Column(
              children: [
                Icon(
                  _afterSaleStatusIcon(value.status),
                  size: 58,
                  color: color,
                ),
                const SizedBox(height: 10),
                Text(
                  value.status.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _afterSaleStatusHint(value),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF667085), height: 1.4),
                ),
                if (value.currentDeadlineAt != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.schedule_rounded, size: 16, color: color),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '请在 ${_date(value.currentDeadlineAt!)} 前处理',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: color,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, Widget child, {required IconData icon}) {
    return Container(
      key: ValueKey('after-sale-section-$title'),
      margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: mallPrimary),
              const SizedBox(width: 7),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF1F2937),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _infoRow(
    String label,
    String value, {
    bool strong = false,
    Color? valueColor,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 86,
          child: Text(label, style: const TextStyle(color: Color(0xFF7E8592))),
        ),
        Expanded(
          child: SelectableText(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: valueColor ?? const Color(0xFF344054),
              fontWeight: strong ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _description(String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF7E8592), fontSize: 13),
        ),
        const SizedBox(height: 5),
        SelectableText(
          value,
          style: const TextStyle(color: Color(0xFF344054), height: 1.55),
        ),
      ],
    ),
  );

  Widget _afterSaleItem(AfterSaleItem item) {
    final quantity = item.approvedQuantity > 0
        ? item.approvedQuantity
        : item.requestedQuantity;
    final amount = item.approvedAmount > 0
        ? item.approvedAmount
        : item.paidAmount;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox.square(
              dimension: 58,
              child: MallNetworkImage(url: item.productImage),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (item.skuName?.isNotEmpty == true)
                  Text(
                    item.skuName!,
                    style: const TextStyle(
                      color: Color(0xFF7E8592),
                      fontSize: 12,
                    ),
                  ),
                const SizedBox(height: 5),
                Text(
                  '数量 $quantity  ·  ¥${amount.toStringAsFixed(2)}',
                  style: const TextStyle(color: Color(0xFF667085)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _trackingLine(String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(child: _infoRow(label, value)),
      const SizedBox(width: 4),
      IconButton(
        tooltip: '复制物流单号',
        visualDensity: VisualDensity.compact,
        onPressed: () => _copy(value),
        icon: const Icon(Icons.copy_outlined, size: 20),
      ),
    ],
  );

  Widget _evidence(String label, List<String> urls) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.photo_library_outlined,
              size: 17,
              color: Color(0xFF7E8592),
            ),
            const SizedBox(width: 6),
            Text(
              '$label（${urls.length}）',
              style: const TextStyle(
                color: Color(0xFF667085),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        AfterSaleEvidenceGrid(urls: urls),
      ],
    ),
  );

  Widget _notice(String text, {required IconData icon, required Color color}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 9),
        Expanded(
          child: Text(text, style: TextStyle(color: color, height: 1.45)),
        ),
      ],
    );
  }

  Widget _timelineItem(AfterSaleLog log, {required bool isLast}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 26,
            child: Column(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE9EDFF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: mallPrimary,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: const Color(0xFFE4E7EC),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _actionLabel(log.action),
                    style: const TextStyle(
                      color: Color(0xFF344054),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      _operatorLabel(log.operatorType),
                      if (log.createdAt != null) _date(log.createdAt!),
                    ].join(' · '),
                    style: const TextStyle(
                      color: Color(0xFF98A2B3),
                      fontSize: 12,
                    ),
                  ),
                  if (log.description?.isNotEmpty == true) ...[
                    const SizedBox(height: 6),
                    Text(
                      log.description!,
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _hasSellerSection(OrderAfterSale value) =>
      value.sellerDecision?.isNotEmpty == true ||
      value.sellerReason?.isNotEmpty == true ||
      value.returnAddress?.isNotEmpty == true;

  bool _hasReturnSection(OrderAfterSale value) =>
      value.returnTrackingNumber?.isNotEmpty == true ||
      value.returnEvidenceUrls.isNotEmpty;

  bool _hasArbitrationSection(OrderAfterSale value) =>
      value.arbitrationReason?.isNotEmpty == true ||
      value.arbitrationDecision?.isNotEmpty == true ||
      value.arbitrationRemark?.isNotEmpty == true ||
      value.arbitrationEvidenceUrls.isNotEmpty;

  Widget? _actions(OrderAfterSale value) {
    if (value.availableActions.isEmpty) return null;
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 12,
              offset: Offset(0, -3),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Wrap(
          alignment: WrapAlignment.end,
          spacing: 10,
          runSpacing: 8,
          children: [
            if (value.hasAction('cancel_after_sale'))
              OutlinedButton.icon(
                onPressed: _acting ? null : _cancel,
                icon: const Icon(Icons.close_rounded),
                label: const Text('取消售后'),
              ),
            if (value.hasAction('approve_after_sale'))
              FilledButton.icon(
                onPressed: _acting ? null : _sellerHandle,
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('处理售后'),
              ),
            if (value.hasAction('submit_return'))
              FilledButton.icon(
                onPressed: _acting ? null : _submitReturn,
                icon: const Icon(Icons.local_shipping_outlined),
                label: const Text('提交退货'),
              ),
            if (value.hasAction('confirm_return'))
              FilledButton.icon(
                onPressed: _acting ? null : _confirmReturn,
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('确认收到退货'),
              ),
            if (value.hasAction('request_arbitration'))
              FilledButton.icon(
                onPressed: _acting ? null : _arbitrate,
                icon: const Icon(Icons.gavel_outlined),
                label: const Text('申请平台仲裁'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final value = await widget.gateway.loadAfterSale(widget.afterSaleId);
      if (mounted) setState(() => _afterSale = value);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sellerHandle() async {
    final value = _afterSale;
    if (value == null) return;
    await Navigator.of(context).push<OrderAfterSale>(
      MaterialPageRoute(
        builder: (_) =>
            SellerAfterSalePage(afterSale: value, gateway: widget.gateway),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _submitReturn() async {
    final value = _afterSale;
    if (value == null) return;
    await Navigator.of(context).push<OrderAfterSale>(
      MaterialPageRoute(
        builder: (_) =>
            ReturnOrderPage(afterSale: value, gateway: widget.gateway),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _arbitrate() async {
    final value = _afterSale;
    if (value == null) return;
    await Navigator.of(context).push<OrderAfterSale>(
      MaterialPageRoute(
        builder: (_) =>
            ArbitrationPage(afterSale: value, gateway: widget.gateway),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _cancel() async {
    final confirmed = await showMallConfirm(
      context,
      title: '取消售后',
      message: '确认取消当前售后申请？',
      confirmText: '确认取消',
    );
    if (!confirmed) return;
    await _run(() => widget.gateway.cancelAfterSale(widget.afterSaleId));
  }

  Future<void> _confirmReturn() async {
    final confirmed = await showMallConfirm(
      context,
      title: '确认收到退货',
      message: '确认已收到买家退回的商品？确认后将执行退款。',
      confirmText: '确认收到',
    );
    if (!confirmed) return;
    await _run(() => widget.gateway.confirmReturn(widget.afterSaleId));
  }

  Future<void> _run(Future<OrderAfterSale> Function() action) async {
    setState(() => _acting = true);
    try {
      _afterSale = await action();
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) showMallMessage(context, '$error', error: true);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) showMallMessage(context, '物流单号已复制');
  }
}

class _AfterSaleFormScaffold extends StatelessWidget {
  const _AfterSaleFormScaffold({
    required this.title,
    required this.children,
    required this.submitting,
    required this.submitLabel,
    required this.onSubmit,
    this.mallStyled = false,
  });

  final String title;
  final List<Widget> children;
  final bool submitting;
  final String submitLabel;
  final VoidCallback onSubmit;
  final bool mallStyled;

  @override
  Widget build(BuildContext context) {
    if (mallStyled) {
      return DecoratedBox(
        key: const ValueKey('after-sale-apply-gradient-background'),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFDEE9FF), Color(0xFFFAFBFF)],
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            toolbarHeight: 58,
            centerTitle: true,
            title: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          body: ListView(
            key: const ValueKey('after-sale-apply-form'),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(10, 2, 10, 24),
            children: children,
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Material(
              color: Colors.white,
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: submitting ? null : onSubmit,
                  child: submitting
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(submitLabel),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(title), centerTitle: true),
      body: ListView(padding: const EdgeInsets.all(16), children: children),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed: submitting ? null : onSubmit,
          child: submitting
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(submitLabel),
        ),
      ),
    );
  }
}

class _AfterSalePanel extends StatelessWidget {
  const _AfterSalePanel({super.key, this.title, required this.child});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: const TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}

class _AfterSaleFieldLabel extends StatelessWidget {
  const _AfterSaleFieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF374151),
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _AfterSaleTypeSelector extends StatelessWidget {
  const _AfterSaleTypeSelector({
    required this.value,
    required this.allowReturnRefund,
    required this.onChanged,
  });

  final AfterSaleType value;
  final bool allowReturnRefund;
  final ValueChanged<AfterSaleType> onChanged;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      key: const ValueKey('after-sale-type-tabs'),
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE3E8F2)),
      ),
      child: Row(
        children: [
          _tab(
            type: AfterSaleType.refundOnly,
            label: '仅退款',
            enabled: true,
            primary: primary,
          ),
          _tab(
            type: AfterSaleType.returnRefund,
            label: '退货退款',
            enabled: allowReturnRefund,
            primary: primary,
          ),
        ],
      ),
    );
  }

  Widget _tab({
    required AfterSaleType type,
    required String label,
    required bool enabled,
    required Color primary,
  }) {
    final selected = value == type;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        enabled: enabled,
        label: enabled ? label : '$label，当前订单状态暂不支持',
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          child: InkWell(
            key: ValueKey('after-sale-type-tab-${type.wireValue}'),
            onTap: enabled && !selected ? () => onChanged(type) : null,
            borderRadius: BorderRadius.circular(7),
            child: AnimatedContainer(
              key: ValueKey('after-sale-type-tab-surface-${type.wireValue}'),
              duration: const Duration(milliseconds: 180),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFE7EEFF) : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: !enabled
                      ? const Color(0xFFB4BAC5)
                      : selected
                      ? primary
                      : const Color(0xFF6B7280),
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AfterSaleItemSelector extends StatelessWidget {
  const _AfterSaleItemSelector({
    required this.item,
    required this.selectedQuantity,
    required this.onChanged,
  });

  final ShopOrderItem item;
  final int selectedQuantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = selectedQuantity > 0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: selected,
          visualDensity: VisualDensity.compact,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          onChanged: item.lineKey.isEmpty
              ? null
              : (checked) => onChanged(checked == true ? item.quantity : 0),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox.square(
            dimension: 64,
            child: MallNetworkImage(url: item.productImage),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.productName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF1F2937),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (item.skuName?.isNotEmpty == true) ...[
                const SizedBox(height: 3),
                Text(
                  item.skuName!,
                  style: const TextStyle(
                    color: Color(0xFF7E8592),
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '¥${(item.actualPaidAmount / item.quantity).toStringAsFixed(2)}/件',
                      style: const TextStyle(
                        color: Color(0xFFE95656),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (selected) _quantityStepper(),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _quantityStepper() {
    return SizedBox(
      height: 34,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton.outlined(
            key: ValueKey('after-sale-minus-${item.lineKey}'),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 34, height: 34),
            tooltip: '减少数量',
            onPressed: selectedQuantity > 1
                ? () => onChanged(selectedQuantity - 1)
                : null,
            icon: const Icon(Icons.remove, size: 17),
          ),
          SizedBox(
            width: 38,
            child: Text(
              '$selectedQuantity',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton.outlined(
            key: ValueKey('after-sale-plus-${item.lineKey}'),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 34, height: 34),
            tooltip: '增加数量',
            onPressed: selectedQuantity < item.quantity
                ? () => onChanged(selectedQuantity + 1)
                : null,
            icon: const Icon(Icons.add, size: 17),
          ),
        ],
      ),
    );
  }
}

const _afterSaleReasonOptions = <({String value, String label})>[
  (value: 'product_issue', label: '商品问题'),
  (value: 'not_as_described', label: '与描述不符'),
  (value: 'damaged', label: '商品损坏'),
  (value: 'other', label: '其他原因'),
];

class _AfterSaleReasonPicker extends StatelessWidget {
  const _AfterSaleReasonPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = _afterSaleReasonOptions.firstWhere(
      (option) => option.value == value,
      orElse: () => _afterSaleReasonOptions.first,
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () => _showPicker(context),
        child: InputDecorator(
          decoration: const InputDecoration(),
          child: Row(
            children: [
              Expanded(child: Text(selected.label)),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    final labels = _afterSaleReasonOptions
        .map((option) => option.label)
        .toList(growable: false);
    final selectedIndex = _afterSaleReasonOptions.indexWhere(
      (option) => option.value == value,
    );
    final style = DefaultPickerStyle(haveRadius: true, title: '选择售后原因')
      ..pickerHeight = 240
      ..pickerTitleHeight = 48
      ..pickerItemHeight = 44
      ..textSize = 14
      ..textColor = const Color(0xFF22252B);

    Pickers.showSinglePicker(
      context,
      data: labels,
      selectData: labels[selectedIndex < 0 ? 0 : selectedIndex],
      pickerStyle: style,
      onConfirm: (_, index) => onChanged(_afterSaleReasonOptions[index].value),
    );
  }
}

Future<void> _pickAndUploadEvidence({
  required BuildContext context,
  required AfterSaleGateway gateway,
  required GalleryMediaPicker galleryMediaPicker,
  required List<String> urls,
  required ValueChanged<bool> setUploading,
  required VoidCallback refresh,
}) async {
  final remaining = 9 - urls.length;
  if (remaining <= 0) return;
  try {
    final images = await galleryMediaPicker.pick(
      context: context,
      mediaType: GalleryMediaType.image,
      allowMultiple: true,
      maxCount: remaining,
      imageQuality: 88,
      maxWidth: 1800,
      maxHeight: 1800,
      onLimitExceeded: (_, maxCount) {
        if (context.mounted) {
          showMallMessage(context, '最多还能选择 $maxCount 张图片', error: true);
        }
      },
    );
    if (images.isEmpty || !context.mounted) return;
    setUploading(true);
    for (final image in images.take(remaining)) {
      final url = await gateway.uploadEvidence(image.path);
      if (!context.mounted) return;
      urls.add(url);
      refresh();
    }
  } catch (error) {
    if (context.mounted) showMallMessage(context, '$error', error: true);
  } finally {
    if (context.mounted) setUploading(false);
  }
}

String _date(DateTime value) {
  final local = value.toLocal();
  String two(int part) => part.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

String _afterSaleReasonLabel(String value) =>
    _afterSaleReasonOptions
        .where((option) => option.value == value)
        .map((option) => option.label)
        .firstOrNull ??
    value;

String _handlerDecisionLabel(String value, AfterSaleHandlerType handlerType) {
  final handler = handlerType == AfterSaleHandlerType.platform ? '平台' : '卖家';
  return {'approved': '$handler已同意', 'rejected': '$handler已拒绝'}[value] ?? value;
}

String _arbitrationDecisionLabel(String value) =>
    const {'support_buyer': '支持买家并退款', 'support_seller': '支持卖家并关闭售后'}[value] ??
    value;

String _operatorLabel(String value) =>
    const {'buyer': '买家', 'seller': '卖家', 'admin': '平台', 'system': '系统'}[value
        .toLowerCase()] ??
    '系统';

Color _afterSaleStatusColor(AfterSaleStatus status) {
  return switch (status) {
    AfterSaleStatus.pendingHandler => const Color(0xFF718AF5),
    AfterSaleStatus.handlerRejected => const Color(0xFFD92D20),
    AfterSaleStatus.handlerTimeout => const Color(0xFFF79009),
    AfterSaleStatus.waitingBuyerReturn => const Color(0xFF1570EF),
    AfterSaleStatus.waitingHandlerReceipt => const Color(0xFF0E9384),
    AfterSaleStatus.arbitrationPending => const Color(0xFF6941C6),
    AfterSaleStatus.refunding => const Color(0xFF1677FF),
    AfterSaleStatus.refunded => const Color(0xFF079455),
    AfterSaleStatus.closed => const Color(0xFF667085),
    AfterSaleStatus.unknown => const Color(0xFF98A2B3),
  };
}

IconData _afterSaleStatusIcon(AfterSaleStatus status) {
  return switch (status) {
    AfterSaleStatus.pendingHandler => Icons.hourglass_top_rounded,
    AfterSaleStatus.handlerRejected => Icons.cancel_outlined,
    AfterSaleStatus.handlerTimeout => Icons.timer_off_outlined,
    AfterSaleStatus.waitingBuyerReturn => Icons.assignment_return_outlined,
    AfterSaleStatus.waitingHandlerReceipt => Icons.local_shipping_outlined,
    AfterSaleStatus.arbitrationPending => Icons.gavel_outlined,
    AfterSaleStatus.refunding => Icons.sync_rounded,
    AfterSaleStatus.refunded => Icons.check_circle_outline_rounded,
    AfterSaleStatus.closed => Icons.lock_outline_rounded,
    AfterSaleStatus.unknown => Icons.help_outline_rounded,
  };
}

String _afterSaleStatusHint(OrderAfterSale value) {
  final handler = value.handlerType == AfterSaleHandlerType.platform
      ? '平台'
      : '卖家';
  return switch (value.status) {
    AfterSaleStatus.pendingHandler => '售后申请已提交，等待$handler处理',
    AfterSaleStatus.handlerRejected =>
      value.handlerType == AfterSaleHandlerType.seller
          ? '卖家已拒绝申请，可在期限内申请平台仲裁'
          : '平台已拒绝申请，本次售后已结束',
    AfterSaleStatus.handlerTimeout =>
      value.handlerType == AfterSaleHandlerType.seller
          ? '卖家处理已超时，可申请平台仲裁'
          : '平台处理已超时，平台会继续跟进',
    AfterSaleStatus.waitingBuyerReturn => '请按$handler提供的地址退回商品',
    AfterSaleStatus.waitingHandlerReceipt => '退货信息已提交，等待$handler确认收货',
    AfterSaleStatus.arbitrationPending => '平台正在审核双方提交的材料',
    AfterSaleStatus.refunding => '退款已提交，正在等待支付渠道处理',
    AfterSaleStatus.refunded => '退款已完成，本次售后已结束',
    AfterSaleStatus.closed => '本次售后已关闭',
    AfterSaleStatus.unknown => '售后状态暂时无法识别',
  };
}

String _actionLabel(String action) =>
    const {
      'create': '发起售后',
      'buyer_cancel': '买家取消售后',
      'seller_approve_return': '卖家同意，等待退货',
      'seller_approve_refund': '卖家同意退款',
      'seller_reject': '卖家拒绝申请',
      'submit_return': '买家提交退货',
      'confirm_return': '卖家确认收到退货',
      'apply_arbitration': '买家申请仲裁',
      'arbitration_support_buyer': '平台支持买家',
      'arbitration_support_seller': '平台支持卖家',
      'seller_timeout': '卖家处理超时',
      'handler_timeout': '处理方处理超时',
      'handler_approve_return': '处理方同意，等待退货',
      'handler_approve_refund': '处理方同意退款',
      'handler_reject': '处理方拒绝申请',
      'platform_approve_return': '平台同意，等待退货',
      'platform_approve_refund': '平台同意退款',
      'platform_reject': '平台拒绝申请',
      'platform_confirm_return': '平台确认收到退货',
      'admin_approve_return': '平台同意，等待退货',
      'admin_approve_refund': '平台同意退款',
      'admin_reject': '平台拒绝申请',
      'timeout_close': '售后超时关闭',
      'buyer_return_timeout_close': '买家退货超时，售后关闭',
      'arbitration_timeout_close': '仲裁申请超时，售后关闭',
      'refund_success': '退款成功',
      'refund_failed': '退款失败',
    }[action] ??
    '售后状态更新';
