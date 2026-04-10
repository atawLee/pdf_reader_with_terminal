# BookApp - PDF Book Supporter

PDF로 책을 읽으면서 이해가 어려운 부분을 **OCR로 추출**하고, 내장 터미널의 **AI CLI(Claude Code 등)에 바로 질문**할 수 있는 데스크톱 학습 도우미 앱.

## 주요 기능

### PDF 뷰어
- 연속 스크롤 보기 (세로 전체 페이지 렌더링)
- 키보드 페이지 이동 (`←` `→` `↑` `↓`)
- 페이지 번호 직접 입력 이동
- 확대/축소, 화면 맞춤

### OCR (광학 문자 인식)
- **전체 페이지 OCR**: 현재 페이지 전체 텍스트 추출
- **영역 지정 OCR**: 드래그로 원하는 영역만 선택하여 텍스트 추출
- Windows 기본 OCR 엔진 사용 (`Windows.Media.Ocr`) - 설치된 언어팩에 따라 한국어/영어/일본어 등 지원
- 추출된 텍스트를 복사하여 터미널의 AI CLI에 바로 붙여넣기 가능

### 페이지별 노트
- 각 페이지마다 독립된 마크다운 노트 작성
- 자동 저장 (1초 디바운스)
- 리사이즈 가능한 좌측 노트 패널 (240px ~ 600px)

### 내장 터미널
- PowerShell / CMD 선택 가능
- `Ctrl+`` 으로 터미널 패널 토글
- 드래그로 터미널 높이 조절
- **한글 입력바** (F1 토글) - IME 한글 입력 지원, 명령 히스토리(`↑` `↓`), `Ctrl+C` 인터럽트

### 사이드바
- 최근 열었던 파일 목록 (최대 20개, 상대 시간 표시)
- 클릭으로 빠른 파일 전환

## 노트 저장 구조

노트는 PDF 파일과 **같은 디렉토리**에 페이지 단위로 저장됩니다.

```
D:\Books\
├── mybook.pdf
├── mybook_1.md      ← 1페이지 노트
├── mybook_2.md      ← 2페이지 노트
├── mybook_15.md     ← 15페이지 노트
└── ...
```

- 형식: 마크다운 (`.md`)
- 파일명: `{PDF파일명}_{페이지번호}.md`
- 빈 노트는 자동 삭제 (빈 파일이 남지 않음)
- 페이지 전환 시 자동 저장 후 다음 페이지 노트 로드
- 위젯 종료 시에도 미저장 내용 즉시 저장

## 사용 흐름

```
1. PDF 열기 → 책 읽기
2. 이해 안 되는 부분 발견 → OCR 영역 지정으로 텍스트 추출
3. 추출된 텍스트 복사 → 터미널의 Claude Code에 붙여넣기로 질문
4. AI 답변을 보며 이해 → 노트에 정리
```

## 프로젝트 구조

```
lib/
├── main.dart                 # 앱 진입점, Catppuccin Mocha 테마
├── models/
│   └── recent_file.dart      # 최근 파일 데이터 클래스
├── providers/
│   └── pdf_providers.dart    # Riverpod 상태 관리
├── services/
│   └── ocr_service.dart      # PDF 렌더링 → PNG → OCR 파이프라인
├── screens/
│   └── home_screen.dart      # 메인 화면 레이아웃
└── widgets/
    ├── pdf_viewer_widget.dart  # PDF 뷰어 + OCR 패널 + 노트 패널
    ├── sidebar_widget.dart     # 최근 파일 사이드바
    └── terminal_widget.dart    # 내장 터미널 + 한글 입력바

windows/runner/
├── ocr_handler.h / .cpp      # Windows OCR 네이티브 구현 (C++/WinRT)
├── flutter_window.cpp        # OCR MethodChannel 등록
└── CMakeLists.txt            # C++/WinRT 빌드 설정
```

## 기술 스택

| 영역 | 기술 |
|------|------|
| 프레임워크 | Flutter (Desktop) |
| 상태 관리 | Riverpod |
| PDF 렌더링 | pdfrx |
| 터미널 | xterm + flutter_pty |
| OCR | Windows.Media.Ocr (C++/WinRT, MethodChannel) |
| 저장 | SharedPreferences (설정), 파일 시스템 (노트) |

## 빌드

```bash
# Windows debug 빌드
flutter build windows --debug

# 실행
.\build\windows\x64\runner\Debug\bookapp.exe
```

## 단축키

| 단축키 | 동작 |
|--------|------|
| `Ctrl+`` | 터미널 토글 |
| `F1` | 한글 입력바 토글 |
| `Esc` | 한글 입력바 닫기 / OCR 영역 지정 취소 |
| `←` `→` `↑` `↓` | 페이지 이동 |
| `Ctrl+C` | 터미널 인터럽트 (입력바 모드) |

## 요구 사항

- Windows 10 이상
- Flutter SDK 3.9+
- OCR 사용 시 Windows 설정에서 해당 언어팩 설치 필요 (한국어, 영어 등)

## 라이선스

[MIT License](LICENSE)
