import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class _Tab {
  const _Tab(this.branch, this.label, this.icon, this.activeIcon, {this.raised = false});

  /// 라우터 [StatefulShellRoute]의 branch 번호 (홈 0 · 코스 1 · 저장됨 2 · 추출 3 · 마이 4)
  final int branch;
  final String label;
  final IconData icon;
  final IconData activeIcon;

  /// 가운데 코스: 검정 사각형으로 바 위에 조금 띄운다 (07 D31)
  final bool raised;
}

/// 보이는 순서: 홈 · 저장됨 · 코스 · 추출 · 마이 (07 D31). branch 순서는 바꾸지 않는다.
const _tabs = [
  _Tab(0, '홈', Icons.home_outlined, Icons.home_rounded),
  _Tab(2, '저장됨', Icons.bookmark_border_rounded, Icons.bookmark_rounded),
  _Tab(1, '코스', Icons.route_outlined, Icons.route_rounded, raised: true),
  _Tab(3, '추출', Icons.add_box_outlined, Icons.add_box_rounded),
  _Tab(4, '마이', Icons.person_outline_rounded, Icons.person_rounded),
];

/// 하단 탭 5개. 활성 탭은 현재 라우트가 속한 branch 기준.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: AppBottomNav(
        currentIndex: shell.currentIndex,
        onTap: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
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

  /// 가운데 버튼 크기. 버튼 아래 끝을 다른 탭 아이콘의 아래 끝(칸 아래에서 29)에 맞춰서
  /// 아이콘-글자 간격이 다섯 탭 모두 같고, 버튼은 바 위로 11 정도 올라온다.
  static const _raisedSize = 44.0;
  static const _raisedBottom = 29.0;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : AppColors.textSecondary;
    final label = Text(
      tab.label,
      style: AppTypography.caption.copyWith(color: color, fontWeight: active ? FontWeight.w700 : FontWeight.w500),
    );
    return Semantics(
      selected: active,
      button: true,
      label: tab.label,
      // 글자가 이름을 겹쳐 읽지 않게 아래 의미는 빼고, 누르기 동작은 여기서 직접 준다
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: tab.raised ? _raised(label) : _plain(color, label),
      ),
    );
  }

  Widget _plain(Color color, Widget label) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 50,
          height: 30,
          decoration: BoxDecoration(
            color: active ? AppColors.primarySoft : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(active ? tab.activeIcon : tab.icon, color: color, size: 23),
        ),
        const SizedBox(height: 3),
        label,
      ],
    );
  }

  /// 바 안에서는 다른 탭과 같은 자리(30)를 비워 두고, 버튼은 바 위로 넘친다.
  Widget _raised(Widget label) {
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [const SizedBox(height: 30), const SizedBox(height: 3), label],
        ),
        Positioned(
          bottom: _raisedBottom,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: _raisedSize,
            height: _raisedSize,
            decoration: BoxDecoration(
              color: active ? AppColors.primary : AppColors.ink,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.surface, width: 3),
              boxShadow: const [BoxShadow(color: Color(0x2E14223A), blurRadius: 6, offset: Offset(0, 2))],
            ),
            child: const Icon(Icons.route_rounded, color: Colors.white, size: 22),
          ),
        ),
      ],
    );
  }
}
