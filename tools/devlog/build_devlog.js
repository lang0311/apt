// 개발 일지 생성기: entries.js → docs/08_DEV_LOG.docx
// 실행: cd tools/devlog && npm install && npm run build
const fs = require('fs');
const path = require('path');
const {
  Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell, WidthType, ShadingType,
  HeadingLevel, AlignmentType, BorderStyle, LevelFormat, Footer, PageNumber,
} = require('docx');

const entries = require('./entries');
const OUT = path.resolve(__dirname, '../../docs/08_DEV_LOG.docx');

const FONT = 'Malgun Gothic';
const C = { primary: '246BFD', text: '132238', sub: '7B8AA3', line: 'D9E1EE', head: 'EEF3FF', ai: 'F39A45', error: 'F0645A', ok: '2E9E6A' };
const STATUS_COLOR = { 완료: C.ok, 해결: C.ok, '진행 중': C.primary, '확인 필요': C.ai, '결정 대기': C.ai, 미해결: C.error };

// A4, 좌우 여백 1.8cm → 본문 폭(DXA)
const PAGE_W = 11906, MARGIN = 1020, BODY_W = PAGE_W - MARGIN * 2;

const run = (text, o = {}) => new TextRun({ text, font: FONT, size: o.size ?? 20, bold: o.bold, color: o.color ?? C.text });
const para = (children, o = {}) =>
  new Paragraph({ children: Array.isArray(children) ? children : [children], spacing: { after: o.after ?? 80, before: o.before ?? 0 }, ...o.extra });
const bullet = (text) =>
  new Paragraph({ numbering: { reference: 'bullets', level: 0 }, children: [run(text)], spacing: { after: 40 } });
const label = (text) => para(run(text, { bold: true, color: C.primary, size: 21 }), { before: 160, after: 60 });
const statusRun = (s) => run(`[${s}]`, { bold: true, color: STATUS_COLOR[s] ?? C.sub });

const border = { style: BorderStyle.SINGLE, size: 4, color: C.line };
const borders = { top: border, bottom: border, left: border, right: border };

function cell(content, width, o = {}) {
  const children = (Array.isArray(content) ? content : [content]).map((c) =>
    c instanceof Paragraph ? c : new Paragraph({ children: [c instanceof TextRun ? c : run(String(c), { size: 18, bold: o.bold })] }),
  );
  return new TableCell({
    children,
    width: { size: width, type: WidthType.DXA },
    borders,
    margins: { top: 60, bottom: 60, left: 100, right: 100 },
    shading: o.fill ? { type: ShadingType.CLEAR, color: 'auto', fill: o.fill } : undefined,
  });
}

function table(headers, rows, ratios) {
  const widths = ratios.map((r) => Math.round(BODY_W * r));
  widths[widths.length - 1] = BODY_W - widths.slice(0, -1).reduce((a, b) => a + b, 0);
  return new Table({
    width: { size: BODY_W, type: WidthType.DXA },
    columnWidths: widths,
    rows: [
      new TableRow({ tableHeader: true, children: headers.map((h, i) => cell(h, widths[i], { bold: true, fill: C.head })) }),
      ...rows.map((r) => new TableRow({ children: r.map((v, i) => cell(v, widths[i])) })),
    ],
  });
}

function entrySection(e) {
  const out = [
    new Paragraph({
      heading: HeadingLevel.HEADING_2,
      children: [run(`${e.id}단계. ${e.title}`, { size: 26, bold: true })],
      spacing: { before: 360, after: 80 },
    }),
    para([run(`${e.date}   `, { color: C.sub, size: 18 }), statusRun(e.status), run(e.commits.length ? `   커밋 ${e.commits.join(', ')}` : '   (코드 변경 없음)', { color: C.sub, size: 18 })]),
    para(run(e.goal, { color: C.sub })),
  ];
  if (e.work.length) out.push(label('작업 내용'), ...e.work.map(bullet));
  out.push(label('발생한 문제와 해결 방법'));
  if (e.problems.length) {
    out.push(
      table(
        ['문제', '원인', '해결 / 제안', '상태'],
        e.problems.map((p) => [p.problem, p.cause, p.solution, statusRun(p.status)]),
        [0.28, 0.25, 0.35, 0.12],
      ),
    );
  } else {
    out.push(para(run('기록된 문제 없음', { color: C.sub })));
  }
  if (e.decisions.length) out.push(label('결정 사항'), ...e.decisions.map(bullet));
  if (e.pending.length) out.push(label('남은 일 / 결정 필요'), ...e.pending.map(bullet));
  return out;
}

const now = new Date();
const today = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;
const openProblems = entries.flatMap((e) => e.problems.filter((p) => p.status !== '해결').map((p) => ({ e, p })));
const openPending = entries.flatMap((e) => e.pending.map((t) => ({ e, t })));

const doc = new Document({
  creator: 'APT 팀',
  title: 'APT 개발 일지',
  styles: {
    default: { document: { run: { font: FONT, size: 20, color: C.text } } },
    paragraphStyles: [
      { id: 'Heading1', name: 'Heading 1', basedOn: 'Normal', next: 'Normal', quickFormat: true, run: { font: FONT, size: 30, bold: true, color: C.text }, paragraph: { spacing: { before: 240, after: 120 }, outlineLevel: 0 } },
      { id: 'Heading2', name: 'Heading 2', basedOn: 'Normal', next: 'Normal', quickFormat: true, run: { font: FONT, size: 26, bold: true, color: C.text }, paragraph: { outlineLevel: 1 } },
    ],
  },
  numbering: { config: [{ reference: 'bullets', levels: [{ level: 0, format: LevelFormat.BULLET, text: '•', alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 400, hanging: 260 } } } }] }] },
  sections: [
    {
      properties: { page: { size: { width: PAGE_W, height: 16838 }, margin: { top: 1134, bottom: 1134, left: MARGIN, right: MARGIN } } },
      footers: {
        default: new Footer({ children: [new Paragraph({ alignment: AlignmentType.CENTER, children: [new TextRun({ children: ['- ', PageNumber.CURRENT, ' -'], font: FONT, size: 16, color: C.sub })] })] }),
      },
      children: [
        para(run('APT 개발 일지', { size: 40, bold: true }), { after: 60 }),
        para(run('가고 싶은 곳을, 하나의 코스로. — Flutter 앱 개발 과정 · 발생한 문제 · 해결 방법', { color: C.sub })),
        para(run(`최종 갱신 ${today} · 총 ${entries.length}단계`, { color: C.sub, size: 18 }), {
          after: 200,
          extra: { border: { bottom: { style: BorderStyle.SINGLE, size: 8, color: C.primary, space: 4 } } },
        }),
        para(run('이 문서는 tools/devlog/entries.js에서 생성된다. 단계가 끝날 때마다 항목을 추가하고 다시 생성한다. 키·Secret 같은 비밀 값은 적지 않는다. 단계 이동은 Word의 탐색 창(보기 → 탐색 창)을 쓴다.', { size: 18, color: C.sub }), { after: 200 }),

        new Paragraph({ heading: HeadingLevel.HEADING_1, children: [run('진행 현황 요약', { size: 30, bold: true })] }),
        table(
          ['단계', '내용', '날짜', '상태', '커밋'],
          entries.map((e) => [String(e.id), e.title, e.date, statusRun(e.status), e.commits.length ? `${e.commits[0]}${e.commits.length > 1 ? ` 외 ${e.commits.length - 1}` : ''}` : '-']),
          [0.07, 0.48, 0.14, 0.13, 0.18],
        ),

        new Paragraph({ heading: HeadingLevel.HEADING_1, children: [run('미해결 문제 · 결정 대기', { size: 30, bold: true })], spacing: { before: 360 } }),
        openProblems.length
          ? table(['단계', '문제', '제안', '상태'], openProblems.map(({ e, p }) => [String(e.id), p.problem, p.solution, statusRun(p.status)]), [0.08, 0.4, 0.38, 0.14])
          : para(run('없음', { color: C.sub })),
        label('남은 일 / 결정 필요'),
        ...openPending.map(({ e, t }) => bullet(`(${e.id}단계) ${t}`)),

        new Paragraph({ heading: HeadingLevel.HEADING_1, children: [run('단계별 기록', { size: 30, bold: true })], spacing: { before: 360 } }),
        ...entries.flatMap(entrySection),
      ],
    },
  ],
});

Packer.toBuffer(doc).then((buf) => {
  fs.writeFileSync(OUT, buf);
  console.log(`생성: ${OUT} (${entries.length}단계, 미해결 ${openProblems.length}건)`);
});
