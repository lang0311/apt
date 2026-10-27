import 'package:apt/features/party/domain/party_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const me = PartyMember(id: 'u1', nickname: '랑', isMe: true);
  PartyMember m(String name) => PartyMember(id: name, nickname: name);

  test('파티 이름: 나를 맨 앞에, 세 명까지, 넘치면 외 n명', () {
    expect([m('민지'), me, m('랑이')].crewNames, '나, 민지, 랑이');
    expect([me, m('도윤')].crewNames, '나, 도윤');
    expect([me, m('민지'), m('랑이'), m('도윤'), m('수아')].crewNames, '나, 민지 외 3명');
  });

  test('알릴 사람: 나를 빼고 두 명까지, 넘치면 외 n명', () {
    expect([me, m('민지'), m('랑이')].otherNames, '민지, 랑이');
    expect([me, m('민지'), m('랑이'), m('도윤')].otherNames, '민지, 랑이 외 1명');
    expect([me].otherNames, '');
  });
}
