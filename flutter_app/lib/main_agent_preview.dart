import 'package:flutter/material.dart';

import 'features/agent/presentation/agent_home_view.dart';

void main() {
  runApp(const AgentPreviewApp());
}

class AgentPreviewApp extends StatelessWidget {
  const AgentPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '谷德E宠 · Agent 预览',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF202F29),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F7F4),
        fontFamilyFallback: const ['PingFang SC', 'Microsoft YaHei'],
      ),
      home: const _PreviewShell(),
    );
  }
}

class _PreviewShell extends StatefulWidget {
  const _PreviewShell();

  @override
  State<_PreviewShell> createState() => _PreviewShellState();
}

class _PreviewShellState extends State<_PreviewShell> {
  int _index = 0;

  void _open(Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  void _routePrompt(String prompt) {
    if (prompt.contains('商城') ||
        prompt.contains('商品') ||
        prompt.contains('主粮') ||
        prompt.contains('订单')) {
      _open(const _MallPreviewPage());
      return;
    }
    if (prompt.contains('社区') ||
        prompt.contains('宠友') ||
        prompt.contains('领养')) {
      setState(() => _index = 1);
      return;
    }
    if (prompt.contains('预约') || prompt.contains('疫苗')) {
      _open(const _AppointmentPreviewPage());
      return;
    }
    _open(const _HealthPreviewPage());
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      AgentHomeView(
        petName: '团团',
        onPrompt: _routePrompt,
        onHealth: () => _open(const _HealthPreviewPage()),
        onShop: () => _open(const _MallPreviewPage()),
        onAppointment: () => _open(const _AppointmentPreviewPage()),
        onCommunity: () => setState(() => _index = 1),
      ),
      const _CommunityPreviewPage(),
      const _MessagePreviewPage(),
      const _ProfilePreviewPage(),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 900;
        if (desktop) {
          return ColoredBox(
            color: const Color(0xFFECEEE9),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1180),
                margin: const EdgeInsets.all(18),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F4),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x24504D45),
                      blurRadius: 70,
                      offset: Offset(0, 24),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _DesktopSidebar(
                      selectedIndex: _index,
                      onSelected: (value) => setState(() => _index = value),
                    ),
                    Expanded(
                      child: IndexedStack(index: _index, children: pages),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return Scaffold(
          body: IndexedStack(index: _index, children: pages),
          bottomNavigationBar: NavigationBar(
            height: 68,
            backgroundColor: const Color(0xFFFBFAF7),
            indicatorColor: const Color(0xFFE5E9E3),
            selectedIndex: _index,
            onDestinationSelected: (value) => setState(() => _index = value),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.auto_awesome_outlined),
                selectedIcon: Icon(Icons.auto_awesome_rounded),
                label: '小谷',
              ),
              NavigationDestination(
                icon: Icon(Icons.people_alt_outlined),
                selectedIcon: Icon(Icons.people_alt_rounded),
                label: '宠友',
              ),
              NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline_rounded),
                selectedIcon: Icon(Icons.chat_bubble_rounded),
                label: '消息',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: '我的',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 232,
      padding: const EdgeInsets.fromLTRB(17, 28, 17, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE8EAE6))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: Color(0xFF202F29),
                child: Text(
                  'G',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SizedBox(width: 11),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '谷德E宠',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '懂宠物，也懂你',
                    style: TextStyle(fontSize: 11, color: Color(0xFF949B96)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: () => onSelected(0),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF202F29),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('新对话'),
          ),
          const SizedBox(height: 25),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 9),
            child: Text(
              '最近对话',
              style: TextStyle(fontSize: 11, color: Color(0xFF9AA19C)),
            ),
          ),
          const SizedBox(height: 8),
          _SidebarConversation(
            text: '团团最近软便怎么办',
            selected: selectedIndex == 0,
            onTap: () => onSelected(0),
          ),
          const _SidebarConversation(text: '挑选适合的主粮'),
          const _SidebarConversation(text: '预约周末疫苗'),
          const _SidebarConversation(text: '查询商城订单'),
          const Spacer(),
          _SidebarNavItem(
            icon: Icons.people_alt_outlined,
            label: '宠友圈',
            selected: selectedIndex == 1,
            onTap: () => onSelected(1),
          ),
          _SidebarNavItem(
            icon: Icons.chat_bubble_outline_rounded,
            label: '消息',
            selected: selectedIndex == 2,
            onTap: () => onSelected(2),
          ),
          _SidebarNavItem(
            icon: Icons.person_outline_rounded,
            label: '我的',
            selected: selectedIndex == 3,
            onTap: () => onSelected(3),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F6F2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(0xFFEAD7B7),
                  child: Icon(Icons.pets_rounded, color: Color(0xFF765D36)),
                ),
                SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '团团',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '柯基 · 2岁 · 5.8kg',
                      style: TextStyle(fontSize: 10, color: Color(0xFF7D857F)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarConversation extends StatelessWidget {
  const _SidebarConversation({
    required this.text,
    this.selected = false,
    this.onTap,
  });

  final String text;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFF1F2EE) : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected
                  ? const Color(0xFF202522)
                  : const Color(0xFF69716C),
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarNavItem extends StatelessWidget {
  const _SidebarNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      selected: selected,
      selectedTileColor: const Color(0xFFF1F2EE),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      leading: Icon(icon, size: 19),
      title: Text(label, style: const TextStyle(fontSize: 12)),
      onTap: onTap,
    );
  }
}

class _PreviewPage extends StatelessWidget {
  const _PreviewPage({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F7F4),
        surfaceTintColor: Colors.transparent,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          Text(subtitle, style: const TextStyle(color: Color(0xFF7D857F))),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }
}

class _MallPreviewPage extends StatelessWidget {
  const _MallPreviewPage();

  @override
  Widget build(BuildContext context) {
    return _PreviewPage(
      title: '为团团精选',
      subtitle: '结合团团 2 岁、5.8kg 和肠胃敏感档案推荐',
      children: [
        const _InfoBanner(
          icon: Icons.auto_awesome_rounded,
          title: '小谷已筛选 12 件商品',
          text: '已自动避开高敏配方，并优先展示支持公益捐赠的商品。',
        ),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: .73,
          children: const [
            _ProductCard(name: '肠胃舒护主粮', price: '¥129', icon: '🥣'),
            _ProductCard(name: '犬用益生菌', price: '¥69', icon: '🧴'),
            _ProductCard(name: '低敏鸡肉冻干', price: '¥89', icon: '🍗'),
            _ProductCard(name: '智能饮水机', price: '¥199', icon: '💧'),
          ],
        ),
      ],
    );
  }
}

class _HealthPreviewPage extends StatelessWidget {
  const _HealthPreviewPage();

  @override
  Widget build(BuildContext context) {
    return const _PreviewPage(
      title: '健康咨询',
      subtitle: 'AI 建议仅用于健康管理参考，紧急情况请及时线下就医',
      children: [
        _InfoBanner(
          icon: Icons.pets_rounded,
          title: '已读取团团档案',
          text: '柯基 · 2 岁 · 5.8kg · 肠胃敏感 · 疫苗已完成',
        ),
        SizedBox(height: 14),
        _ConversationCard(),
      ],
    );
  }
}

class _AppointmentPreviewPage extends StatelessWidget {
  const _AppointmentPreviewPage();

  @override
  Widget build(BuildContext context) {
    return const _PreviewPage(
      title: '预约服务',
      subtitle: '已根据团团档案匹配附近医院',
      children: [
        _AppointmentCard(),
        SizedBox(height: 12),
        _AppointmentCard(second: true),
      ],
    );
  }
}

class _CommunityPreviewPage extends StatelessWidget {
  const _CommunityPreviewPage();

  @override
  Widget build(BuildContext context) {
    return const _SimpleTabPage(
      title: '宠友圈',
      subtitle: '团团附近的宠友和活动',
      cards: [
        _SocialCard(
          name: '可乐和妈妈',
          meta: '2.3km · 12分钟前',
          text: '下午准备带可乐去滨江草坪，有一起遛狗的小伙伴吗？',
          accent: Color(0xFF8FA06C),
        ),
        _SocialCard(
          name: '城西领养站',
          meta: '公益机构 · 1小时前',
          text: '三个月大的橘猫“年糕”正在寻找新家，已完成驱虫和基础体检。',
          accent: Color(0xFFD5A86C),
        ),
      ],
    );
  }
}

class _MessagePreviewPage extends StatelessWidget {
  const _MessagePreviewPage();

  @override
  Widget build(BuildContext context) {
    return const _SimpleTabPage(
      title: '消息',
      subtitle: '医生、订单和宠友消息',
      cards: [
        _SocialCard(
          name: '林医生',
          meta: '刚刚',
          text: '团团今晚可以继续观察，记得记录排便次数。',
          accent: Color(0xFF66869A),
        ),
        _SocialCard(
          name: '订单动态',
          meta: '30分钟前',
          text: '肠胃舒护主粮已发货，预计明天送达。',
          accent: Color(0xFF8D78A1),
        ),
      ],
    );
  }
}

class _ProfilePreviewPage extends StatelessWidget {
  const _ProfilePreviewPage();

  @override
  Widget build(BuildContext context) {
    return const _SimpleTabPage(
      title: '我的',
      subtitle: '管理团团的档案、订单和预约',
      cards: [
        _SocialCard(
          name: '团团 · 柯基',
          meta: '2 岁 · 5.8kg',
          text: '健康档案完整度 86% · 下次疫苗 10月12日',
          accent: Color(0xFF5C7A6C),
        ),
      ],
    );
  }
}

class _SimpleTabPage extends StatelessWidget {
  const _SimpleTabPage({
    required this.title,
    required this.subtitle,
    required this.cards,
  });

  final String title;
  final String subtitle;
  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text(subtitle, style: const TextStyle(color: Color(0xFF7D857F))),
          const SizedBox(height: 20),
          ...cards.expand((card) => [card, const SizedBox(height: 12)]),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EEE9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF4E6C5B)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6F7972),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.name,
    required this.price,
    required this.icon,
  });

  final String name;
  final String price;
  final String icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EAE6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF2EFE8),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(icon, style: const TextStyle(fontSize: 42)),
            ),
          ),
          const SizedBox(height: 11),
          Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Text(
            price,
            style: const TextStyle(
              color: Color(0xFFEF7651),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationCard extends StatelessWidget {
  const _ConversationCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '团团这两天有点软便，精神还可以。',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 15),
          Text(
            '小谷建议',
            style: TextStyle(
              color: Color(0xFF567666),
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 7),
          Text(
            '先观察 24 小时，暂停零食并保证饮水。若持续软便、出现便血或精神变差，请及时联系医生。',
            style: TextStyle(height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({this.second = false});

  final bool second;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: second
                ? const Color(0xFFE8E2F1)
                : const Color(0xFFE1ECE6),
            child: const Icon(Icons.local_hospital_outlined),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  second ? '康贝宠物医院' : '林医生 · 犬猫内科',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  second ? '1.8km · 今日可预约' : '从业 8 年 · 今天 14:30',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF7D857F),
                  ),
                ),
              ],
            ),
          ),
          FilledButton(onPressed: () {}, child: const Text('预约')),
        ],
      ),
    );
  }
}

class _SocialCard extends StatelessWidget {
  const _SocialCard({
    required this.name,
    required this.meta,
    required this.text,
    required this.accent,
  });

  final String name;
  final String meta;
  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: accent,
                child: const Icon(Icons.pets, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      meta,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF8B928D),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Text(text, style: const TextStyle(height: 1.55)),
        ],
      ),
    );
  }
}
