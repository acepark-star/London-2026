#!/bin/bash
# ============================================================
#  런던 여행 웹앱 — GitHub 자동 배포
#  이 파일을 더블클릭하면 현재 폴더 전체를 GitHub에 올립니다.
#  (GitHub Pages가 켜져 있으면 웹사이트도 1~2분 뒤 자동 갱신)
#
#  * 처음 한 번만 GitHub 저장소 주소를 물어봅니다.
#  * git 로그인(토큰/SSH)이 안 돼 있으면 푸시할 때 인증창이 뜹니다.
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
echo "🚀 GitHub로 업로드 중..."
if git push -u origin main; then
  echo ""
  echo "🎉 배포 완료! GitHub Pages가 켜져 있으면 1~2분 뒤 사이트가 갱신됩니다."
  echo "   (저장소 Settings → Pages 에서 상태 확인)"
else
  echo ""
  echo "❌ 업로드 실패. 아래를 확인하세요:"
  echo "   - GitHub 로그인/토큰(또는 SSH 키)이 설정돼 있는지"
  echo "   - 저장소 주소가 맞는지 (git remote -v 로 확인)"
  echo "   - 원격에 먼저 올라간 변경이 있으면: git pull --rebase 후 다시 실행"
fi

echo ""
read -n1 -r -p "창을 닫으려면 아무 키나 누르세요..."; echo
