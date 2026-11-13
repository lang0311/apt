import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../party/presentation/party_providers.dart';
import '../../domain/course_models.dart';
import 'course_timeline.dart';

/// 일정 카드 맨 위 반영한 취향 (07 D46). 파티 코스는 파티원 이름을 받아 와서 펼쳐 볼 수 있게 한다.
/// 파티원을 아직 못 받았거나 받지 못하면 한 줄만 보여 준다.
class AppliedTasteSection extends ConsumerWidget {
  const AppliedTasteSection({super.key, required this.taste, required this.stops, this.partyId});
  final AppliedTaste taste;
  final List<CourseStop> stops;
  final String? partyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = partyId;
    final members = id == null || !taste.hasDetail ? null : ref.watch(partyProvider(id)).value?.members;
    return AppliedTasteLine(taste: taste, stops: stops, members: members);
  }
}
