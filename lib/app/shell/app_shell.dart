import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/saved/presentation/saved_selection.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class _Tab {
  const _Tab(this.branch, this.label, this.icon, this.activeIcon);

  /// 라우터 [StatefulShellRoute]의 branch 번호 (홈 0 · 코스 1 · 저장됨 2 · 추출 3 · 마이 4)
  final int branch;
  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// 보이는 순서: 홈 · 저장됨 · 코스 · 추출 · 마이 (07 D31). branch 순서는 바꾸지 않는다.
const _tabs = [
  _Tab(0, '홈', Icons.home_outlined, Icons.home_rounded),
  _Tab(2, '저장됨', Icons.bookmark_border_rounded, Icons.bookmark_rounded),
  _Tab(1, '코스', Icons.route_outlined, Icons.route_rounded),
  _Tab(3, '장소 추가', Icons.add_box_outlined, Icons.add_box_rounded),
  _Tab(4, '마이', Icons.person_outline_rounded, Icons.person_rounded),
];

/// 하단 탭 5개. 활성 탭은 현재 라우트가 속한 branch 기준.
/// 저장됨에서 여러 곳을 고르는 중에는 하단 탭을 숨기고, 저장됨 화면이 그 자리에 삭제 버튼을 둔다 (07 D45).
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  static const _savedBranch = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selecting = shell.currentIndex == _savedBranch && ref.watch(savedSelectionProvider).active;
    return Scaffold(
      body: shell,
      bottomNavigationBar: selecting
          ? null
          : AppBottomNav(
              currentIndex: shell.currentIndex,
              onTap: (i) {
                ref.read(savedSelectionProvider.notifier).exit();
                shell.goBranch(i, initialLocation: i == shell.currentIndex);
              },
            ),
    );
  }
}

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.currentIndex, required this.onTap});

  /// 지금 branch 번호
  final int currentIndex;

  /// 누른 탭의 branch 번호
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (final tab in _tabs)
                Expanded(
                  child: _NavItem(tab: tab, active: tab.branch == currentIndex, onTap: () => onTap(tab.branch)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.tab, required this.active, required this.onTap});
  final _Tab tab;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.textPrimary : AppColors.textHint;
    final label = Text(
      tab.label,
      style: AppTypography.caption.copyWith(
        color: active ? AppColors.textPrimary : AppColors.textTertiary,
        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    return Semantics(
      selected: active,
      button: true,
      label: tab.label,
      // 글자가 이름을 겹쳐 읽지 않게 아래 의미는 빼고, 누르기 동작은 여기서 직접 준다
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(onTap: onTap, child: _plain(color, label)),
    );
  }

  Widget _plain(Color color, Widget label) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 50,
          height: 28,
          child: Icon(active ? tab.activeIcon : tab.icon, color: color, size: 24),
        ),
        const SizedBox(height: 3),
        label,
      ],
    );
  }
}
