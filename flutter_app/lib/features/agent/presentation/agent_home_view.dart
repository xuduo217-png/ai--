import 'package:flutter/material.dart';

typedef AgentPromptHandler = void Function(String prompt);

class AgentHomeView extends StatefulWidget {
  const AgentHomeView({
    super.key,
    required this.petName,
    required this.onPrompt,
    required this.onHealth,
    required this.onShop,
    required this.onAppointment,
    required this.onCommunity,
  });

  final String petName;
  final AgentPromptHandler onPrompt;
  final VoidCallback onHealth;
  final VoidCallback onShop;
  final VoidCallback onAppointment;
  final VoidCallback onCommunity;

  @override
  State<AgentHomeView> createState() => _AgentHomeViewState();
}

class _AgentHomeViewState extends State<AgentHomeView> {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocus = FocusNode();

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _submit([String? value]) {
    final prompt = (value ?? _inputController.text).trim();
    if (prompt.isEmpty) return;
    _inputController.clear();
    _inputFocus.unfocus();
    widget.onPrompt(prompt);
  }

  @override
  Widget build(BuildContext context) {
    final petName = widget.petName.trim().isEmpty ? '我的宠物' : widget.petName;
    return ColoredBox(
      color: const Color(0xFFF7F7F4),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _AgentHeader(petName: petName),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _AgentMark(),
                        const SizedBox(height: 22),
                        _MemoryChip(petName: petName),
                        const SizedBox(height: 12),
                        const Text(
                          '你好，我是小谷',
                          style: TextStyle(
                            color: Color(0xFF202522),
                            fontSize: 34,
                            height: 1.12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$petName的健康、饮食、预约和订单，都可以直接问我。',
                          style: const TextStyle(
                            color: Color(0xFF7D857F),
                            fontSize: 15,
                            height: 1.55,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _AgentAction(
                          icon: Icons.monitor_heart_outlined,
                          iconBackground: const Color(0xFFFFE2D5),
                          iconColor: const Color(0xFFA94E32),
                          title: '$petName有点不舒服',
                          subtitle: '描述症状，我会结合档案给出建议',
                          onTap: widget.onHealth,
                        ),
                        const SizedBox(height: 10),
                        _AgentAction(
                          icon: Icons.shopping_bag_outlined,
                          iconBackground: const Color(0xFFDFE9FF),
                          iconColor: const Color(0xFF49648B),
                          title: '帮$petName挑选商品',
                          subtitle: '按年龄、体重和健康情况智能推荐',
                          onTap: widget.onShop,
                        ),
                        const SizedBox(height: 10),
                        _AgentAction(
                          icon: Icons.calendar_month_outlined,
                          iconBackground: const Color(0xFFE4F0DC),
                          iconColor: const Color(0xFF557148),
                          title: '预约医生或疫苗',
                          subtitle: '查找合适医院和可预约时间',
                          onTap: widget.onAppointment,
                        ),
                        const SizedBox(height: 10),
                        _AgentAction(
                          icon: Icons.people_alt_outlined,
                          iconBackground: const Color(0xFFF1E4F7),
                          iconColor: const Color(0xFF76558A),
                          title: '看看附近宠友',
                          subtitle: '同城动态、线下活动和领养信息',
                          onTap: widget.onCommunity,
                        ),
                        const SizedBox(height: 16),
                        _AgentMemory(petName: petName),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _Composer(
              controller: _inputController,
              focusNode: _inputFocus,
              onSubmitted: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _AgentHeader extends StatelessWidget {
  const _AgentHeader({required this.petName});

  final String petName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 14, 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE8EAE6))),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFF202F29),
              shape: BoxShape.circle,
            ),
            child: const Text(
              'G',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '小谷',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 2),
                Text(
                  '专属宠物 Agent',
                  style: TextStyle(color: Color(0xFF8A928C), fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: const Color(0xFFE8EAE6)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.pets_rounded,
                  size: 15,
                  color: Color(0xFF68706B),
                ),
                const SizedBox(width: 6),
                Text(petName, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentMark extends StatelessWidget {
  const _AgentMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 66,
      height: 66,
      decoration: BoxDecoration(
        color: const Color(0xFF202F29),
        borderRadius: BorderRadius.circular(21),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F1F3028),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: const Icon(Icons.pets_rounded, size: 34, color: Color(0xFFDFF26B)),
    );
  }
}

class _MemoryChip extends StatelessWidget {
  const _MemoryChip({required this.petName});

  final String petName;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFEDEFEB),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Text(
          '已连接$petName的健康档案',
          style: const TextStyle(color: Color(0xFF68706B), fontSize: 11),
        ),
      ),
    );
  }
}

class _AgentAction extends StatelessWidget {
  const _AgentAction({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE8EAE6)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 23),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF8B928D),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 29,
                height: 29,
                decoration: const BoxDecoration(
                  color: Color(0xFFF3F4F1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.north_east_rounded,
                  size: 16,
                  color: Color(0xFF737B75),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgentMemory extends StatelessWidget {
  const _AgentMemory({required this.petName});

  final String petName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF1EC),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome, size: 17, color: Color(0xFF778D31)),
          const SizedBox(width: 11),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: '小谷记得\n',
                    style: TextStyle(
                      color: Color(0xFF3E4741),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(text: '$petName的档案会用于后续健康建议和商品推荐。'),
                ],
              ),
              style: const TextStyle(
                color: Color(0xFF68706B),
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 9, 14, 12),
      decoration: const BoxDecoration(color: Color(0xFFF7F7F4)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 680),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.fromLTRB(16, 6, 7, 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(21),
          border: Border.all(color: const Color(0xFFDADeda)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1426332C),
              blurRadius: 28,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                textInputAction: TextInputAction.send,
                onSubmitted: onSubmitted,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: '问健康、挑商品、约医生……',
                  hintStyle: TextStyle(color: Color(0xFFA1A7A2), fontSize: 13),
                ),
              ),
            ),
            IconButton.filled(
              onPressed: () => onSubmitted(controller.text),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF202F29),
              ),
              icon: const Icon(
                Icons.arrow_upward_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
