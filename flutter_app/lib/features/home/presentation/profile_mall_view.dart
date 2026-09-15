import 'package:flutter/material.dart';

@Deprecated('Legacy compatibility view. Use ProfilePage with ProfileNavigator.')
class ProfileMallView extends StatelessWidget {
  const ProfileMallView({
    super.key,
    required this.displayName,
    required this.onOrders,
    required this.onAddresses,
    required this.onFavorites,
    required this.onPublishedProducts,
    this.onLogout,
  });

  final String displayName;
  final VoidCallback onOrders;
  final VoidCallback onAddresses;
  final VoidCallback onFavorites;
  final VoidCallback onPublishedProducts;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF5F7FA),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Color(0xFFE8ECFF),
                  child: Icon(
                    Icons.person_outline,
                    size: 34,
                    color: Color(0xFF718AF5),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName.isEmpty ? '我的' : displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '商城服务',
                        style: TextStyle(color: Color(0xFF858C99)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              '我的服务',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _ProfileEntry(
                    icon: Icons.shopping_cart_outlined,
                    iconColor: Color(0xFF8B5CF6),
                    iconBackground: Color(0xFFF3E8FF),
                    title: '商城订单',
                    subtitle: '查看全部商城订单',
                    onTap: onOrders,
                  ),
                  Divider(height: 1, indent: 68),
                  _ProfileEntry(
                    icon: Icons.location_on_outlined,
                    iconColor: Color(0xFF6366F1),
                    iconBackground: Color(0xFFEEF2FF),
                    title: '收货地址',
                    subtitle: '管理您的收货地址',
                    onTap: onAddresses,
                  ),
                  Divider(height: 1, indent: 68),
                  _ProfileEntry(
                    icon: Icons.favorite_border,
                    iconColor: Color(0xFFEC4899),
                    iconBackground: Color(0xFFFCE7F3),
                    title: '我的收藏',
                    subtitle: '查看收藏的商品',
                    onTap: onFavorites,
                  ),
                  Divider(height: 1, indent: 68),
                  _ProfileEntry(
                    icon: Icons.storefront_outlined,
                    iconColor: Color(0xFF8B5CF6),
                    iconBackground: Color(0xFFF3E8FF),
                    title: '我发布商品',
                    subtitle: '查看我发布的商品',
                    onTap: onPublishedProducts,
                  ),
                ],
              ),
            ),
            if (onLogout != null) ...[
              const SizedBox(height: 22),
              OutlinedButton.icon(
                onPressed: onLogout,
                icon: const Icon(Icons.logout),
                label: const Text('退出登录'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileEntry extends StatelessWidget {
  const _ProfileEntry({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: 72,
      onTap: onTap,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: iconBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: iconColor, size: 23),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
