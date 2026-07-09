#!/bin/bash
# ============================================================
#  런던 여행 웹앱 — GitHub 자동 배포
#  이 파일을 더블클릭하면 현재 폴더 전체를 GitHub에 올립니다.
#  (GitHub Pages / Vercel 연결 시 1~2분 뒤 사이트가 자동 갱신)
#
#  * 처음 한 번만 GitHub 저장소 주소를 물어봅니다.
#  * git 로그인(토큰/SSH)이 안 돼 있으면 푸시할 때 인증창이 뜹니다.
#  * 배포 시 바뀐 내용이 있으면 오프라인 캐시(service-worker.js) 버전을
#    자동으로 올려, 사용자 휴대폰에 최신 화면·바우처가 다시 캐시됩니다.
# ============================================================

cd "$(dirname "$0")" || exit 1

echo "================================================"
echo "  런던 여행 웹앱 배포"
echo "  폴더: $(pwd)"
echo "================================================"
echo ""

# 1) git 설치 확인
if ! command -v git >/dev/null 2>&1; then
  echo "❌ git이 설치되어 있지 않습니다."
  echo "   https://git-scm.com 에서 설치한 뒤 다시 실행하세요."
  read -n1 -r -p "종료하려면 아무 키나 누르세요..."; echo; exit 1
fi

# 2) git 저장소 초기화 (최초 1회)
if [ ! -d .git ]; then
  echo "📦 git 저장소를 새로 만듭니다..."
  git init >/dev/null
  git branch -M main
fi

# 3) GitHub Pages가 파일을 임의로 가공하지 않도록
touch .nojekyll

# 3-1) 토큰을 맥 키체인에 저장 → 다음 실행부터는 다시 안 물어봄
git config credential.helper osxkeychain 2>/dev/null || true

# 4) 원격(origin) 저장소 주소 설정 (최초 1회)
if ! git remote get-url origin >/dev/null 2>&1; then
  echo ""
  echo "▶ GitHub 저장소 주소가 아직 없습니다."
  echo "   예) https://github.com/사용자명/저장소이름.git"
  read -r -p "   저장소 주소를 붙여넣고 Enter: " REPO_URL
  if [ -z "$REPO_URL" ]; then
    echo "❌ 주소가 비어 있어 종료합니다."
    read -n1 -r -p "아무 키나 누르세요..."; echo; exit 1
  fi
  git remote add origin "$REPO_URL"
  echo "✅ 원격 저장소 등록: $REPO_URL"
fi

# 4-0) 바우처 프리캐시 목록 자동 생성
#   vouchers/ 폴더를 읽어 vouchers-precache.js 를 다시 만듭니다.
#   (파일명은 원본 그대로 넣고, 인코딩은 service-worker.js 가 실행 시 처리)
#   바우처를 추가/삭제해도 이 파일이 자동으로 바뀌므로 오프라인 캐시 목록이 항상 최신입니다.
if [ -d vouchers ]; then
  {
    echo "// 자동 생성 파일 — 배포 스크립트가 vouchers/ 폴더를 읽어 갱신합니다. 직접 수정하지 마세요."
    echo "self.VOUCHER_FILES = ["
    first=1
    for f in vouchers/*; do
      b=$(basename "$f")
      case "$b" in README*|.*) continue;; esac
      [ -f "$f" ] || continue
      esc=$(printf '%s' "$b" | sed 's/\\/\\\\/g; s/"/\\"/g')
      if [ $first -eq 1 ]; then first=0; else printf ',\n'; fi
      printf '  "%s"' "$esc"
    done
    printf '\n];\n'
  } > vouchers-precache.js
  echo "📄 바우처 프리캐시 목록 갱신: $(grep -c '"' vouchers-precache.js)개 파일"
fi

# 4-1) 오프라인 캐시 버전 자동 증가
#   service-worker.js 를 뺀 나머지 파일에 바뀐 게 있으면(=배포할 내용이 있으면)
#   service-worker.js 의 VERSION 을 +1 해서, 사용자 휴대폰이 새 index.html·바우처를
#   다시 내려받아 캐시하도록 강제합니다. (버전이 그대로면 재캐시가 안 일어남)
#   ※ manifest.webmanifest 는 앱 이름·아이콘이 바뀔 때만 손보면 되고, 여기선 건드리지 않습니다.
if [ -f service-worker.js ]; then
  CHANGED=$(git status --porcelain -- . ':(exclude)service-worker.js' 2>/dev/null)
  if [ -n "$CHANGED" ]; then
    CUR=$(grep -oE "london-2026-v[0-9]+" service-worker.js | head -1)
    if [ -n "$CUR" ]; then
      N=$(printf '%s' "$CUR" | grep -oE "[0-9]+$")
      NEW="london-2026-v$((N+1))"
      # macOS(BSD) sed 는 -i 뒤에 빈 인자('')가 필요합니다.
      sed -i '' -E "s/london-2026-v[0-9]+/$NEW/g" service-worker.js
      echo "🔄 오프라인 캐시 버전 올림: $CUR → $NEW"
    else
      echo "⚠️  service-worker.js 에서 'london-2026-vN' 버전 문자열을 못 찾았습니다. (수동 확인 필요)"
    fi
  else
    echo "ℹ️  바뀐 파일이 없어 캐시 버전은 그대로 둡니다."
  fi
fi

# 5) 변경사항 커밋
git add -A
if git diff --cached --quiet; then
  echo "ℹ️  새로 바뀐 내용이 없습니다. (그래도 푸시를 시도합니다)"
else
  MSG="update: $(date '+%Y-%m-%d %H:%M')"
  git commit -m "$MSG" >/dev/null
  echo "✅ 커밋 완료 — $MSG"
fi

# 6) 푸시
echo ""
echo "🔑 로그인 안내 (처음 한 번만):"
echo "   • Username → GitHub 사용자명만 입력 (예: acepark-star)  ※ 저장소 경로 X"
echo "   • Password → 계정 비밀번호가 아니라 'Personal Access Token'을 붙여넣기"
echo "     토큰 만들기: github.com → 우측상단 프로필 → Settings"
echo "       → Developer settings → Personal access tokens → Tokens (classic)"
echo "       → Generate new token → 'repo' 권한 체크 → 생성 후 복사해서 붙여넣기"
echo "   (한 번 입력하면 맥 키체인에 저장돼 다음부터는 안 물어봅니다)"
echo ""
echo "🚀 GitHub로 업로드 중..."
SUCCESS=0
if git push -u origin main; then
  SUCCESS=1
else
  echo ""
  echo "🔄 원격에 먼저 올라간 내용(README 등)이 있어 병합 후 다시 시도합니다..."
  # 원격 내용과 합치기 (충돌 시 내 파일 우선). 커밋 편집창 없이 진행.
  if git pull --no-edit --no-rebase --allow-unrelated-histories -X ours origin main; then
    if git push -u origin main; then
      SUCCESS=1
    fi
  fi
fi

if [ "$SUCCESS" = "1" ]; then
  echo ""
  echo "🎉 배포 완료! GitHub Pages/Vercel 연결 시 1~2분 뒤 사이트가 갱신됩니다."
  echo "   (사용자 휴대폰은 다음에 '온라인'으로 앱을 열 때 최신본이 다시 캐시됩니다)"
else
  echo ""
  echo "❌ 업로드 실패. 아래를 확인하세요:"
  echo "   - GitHub 로그인/토큰(또는 SSH 키)이 설정돼 있는지"
  echo "   - 저장소 주소가 맞는지 (git remote -v 로 확인)"
  echo "   - 병합 충돌이 났다면 터미널에서 'git status'로 확인 후 해결"
fi

echo ""
read -n1 -r -p "창을 닫으려면 아무 키나 누르세요..."; echo
