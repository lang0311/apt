# 피그마 흐름도 제작 도구

앱 화면을 에뮬레이터에서 열어 화면 요소(상자 · 글자 · 아이콘 · 사진 · 눌러지는 곳)를 뽑고, SVG로 바꿔 피그마에 올린다.
올린 화면은 편집 가능한 텍스트 · 벡터로 들어온다. 2026-11-19 피그마 개인 파일 페이지4(54화면)를 이렇게 만들었다.

> 개인 작업 도구라 팀 레포 `mobile/`에는 반영하지 않는다. **계정 · 키는 코드에 넣지 않는다**(아래 환경 변수로만).

## 구성

| 위치 | 하는 일 |
|---|---|
| `integration_test/_figma/dump.dart` | 렌더 트리를 JSON · PNG로 뽑아 표준출력(base64)으로 내보낸다 |
| `integration_test/_figma/scenes_mock.dart` | Mock 모드로 화면 54개로 이동하며 덤프 (흐름 S1~S9) |
| `integration_test/_figma/scenes_server.dart` | 서버 모드로 덤프 (흐름 V1~V5). 코스 저장은 하지 않는다 |
| `integration_test/_figma/app_classes.dart` | 앱 위젯 클래스 이름 목록(자동 생성, 아래 명령) |
| `tools/figma/run_scenes.sh` · `run_srv.sh` | 위 테스트를 돌리고 로그에서 JSON · PNG를 복원 |
| `tools/figma/parse_dump.py` | 로그의 `FIGDUMP` 줄을 파일로 복원 (멈춘 실행도 복원 가능) |
| `tools/figma/to_svg.py` | JSON → SVG 변환 (Material 아이콘은 SDK 폰트에서 벡터로 뽑음) |
| `tools/figma/taps.py` · `gen_layout.py` | 누르는 곳 정리, 화면 제목 · 흐름 규칙 · 동작 표 데이터 생성 |

파일 이름이 `_test.dart`로 끝나지 않으므로 `flutter test integration_test`(A~L 흐름)에는 섞이지 않는다.

## 순서

작업 폴더는 `$FIGMA_WORK`(기본 `build/figma_work`, gitignore 대상)이다. 에뮬레이터(Pixel_6_Pro)를 켜 둔다.
에뮬레이터 메모리가 차면 테스트가 멈추니 묶음을 나눠 돌리고, 필요하면 `adb shell am kill-all`.

```bash
# 앱 위젯 클래스 목록 갱신 (앱 코드가 바뀌었을 때)
{ echo "// 자동 생성"; echo "const appClassNames = <String>{"; grep -rhoE "^(abstract )?class [A-Za-z0-9_]+ extends (StatelessWidget|StatefulWidget|ConsumerWidget|ConsumerStatefulWidget)" lib | sed -E 's/^(abstract )?class ([A-Za-z0-9_]+).*/  "\2",/' | sort -u; echo "};"; } > integration_test/_figma/app_classes.dart

# 1) Mock 화면 (서버에 없는 기능)
tools/figma/run_scenes.sh m1 --name "S[134]"
tools/figma/run_scenes.sh m2 --name "S[5-8]"

# 2) 서버 화면: 팀 서버를 켜고(tools/start_server.ps1), 계정은 환경 변수로
export APT_DEMO_USER=... APT_DEMO_PW=...
tools/figma/run_srv.sh s1 --name "V[1-5]"

# 3) 합치기 (서버 결과가 Mock보다 우선) → SVG 변환 → 레이아웃 데이터
cd "$FIGMA_WORK"      # final/ 에 dump/ 를 복사하고 dump_srv/ 로 덮어쓴 뒤
python <repo>/tools/figma/to_svg.py final svg
python <repo>/tools/figma/gen_layout.py      # layout.json
```

그 뒤 `upload_assets`(Figma MCP)로 SVG를 올리고, `use_figma`로 섹션 · 핫스팟 · 동작 표 · 화살표를 얹는다.

## 알려진 한계

- 입력칸에 친 글자(`RenderEditable`)는 뽑지 않는다.
- 페이지3의 컴포넌트 세트 · 아이콘 컴포넌트는 만들지 않는다(레이어는 위젯 클래스 이름 그룹).
- 동작 표의 결과는 `gen_layout.py`의 규칙으로 채우며, 앱에서 눌러 확인한 값이 아니다.
- AI 추천 결과(4/4)는 서버 작업이 4분 넘게 걸릴 수 있어 서버 모드 장면에서는 호출하지 않는다.
