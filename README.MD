# SSH Key Setup Script

우분투 서버에서 SSH 키를 자동으로 생성하고, 임시 웹서버를 통해 키를 다운로드할 수 있게 해주는 스크립트입니다.

## 🚀 빠른 시작

```bash
# 스크립트 다운로드
wget https://raw.githubusercontent.com/KORThomasJeong/ubuntukey/main/setup_ssh.sh

# 실행 권한 부여
chmod +x setup_ssh.sh

# 실행
./setup_ssh.sh
```

## 📋 기능

- ✅ SSH 서버/클라이언트 자동 설치
- ✅ RSA 4096비트 SSH 키 자동 생성
- ✅ 임시 Python 웹서버를 통한 키 다운로드
- ✅ 웹 인터페이스 제공 (브라우저에서 편리한 다운로드)
- ✅ 자동 타임아웃 (보안을 위한 서버 자동 종료)
- ✅ 키 권한 설정 가이드 제공
- ✅ SSH 연결 테스트 명령어 제공

## 📖 사용법

### 기본 사용

```bash
./setup_ssh.sh
```

- 키 이름: `id_rsa`
- 포트: `8000`
- 타임아웃: `300초` (5분)

### 사용자 정의 옵션

```bash
./setup_ssh.sh [키_이름] [포트번호] [타임아웃_초]
```

**예시:**
```bash
# 커스텀 키 이름과 포트 사용
./setup_ssh.sh my_server_key 9000 600

# 기본 키 이름, 커스텀 포트
./setup_ssh.sh id_rsa 8080

# 모든 옵션 커스텀
./setup_ssh.sh production_key 7777 900
```

## 🌐 키 다운로드 방법

스크립트 실행 후 표시되는 정보를 참고하여 다른 머신에서 키를 다운로드할 수 있습니다.

### 웹 브라우저 사용 (권장)

```
http://SERVER_IP:PORT/
```

웹 인터페이스에서 클릭으로 간편하게 다운로드 가능합니다.

### 명령줄 사용

#### wget 사용
```bash
wget http://SERVER_IP:PORT/키이름
wget http://SERVER_IP:PORT/키이름.pub
```

#### curl 사용
```bash
curl -O http://SERVER_IP:PORT/키이름
curl -O http://SERVER_IP:PORT/키이름.pub
```

### 다운로드 후 설정

```bash
# 권한 설정 (중요!)
chmod 600 키이름
chmod 644 키이름.pub

# SSH 디렉토리에 이동 (선택사항)
mv 키이름 ~/.ssh/
mv 키이름.pub ~/.ssh/

# SSH 연결 테스트
ssh -i 키이름 username@SERVER_IP
```

## 🔒 보안 고려사항

### ⚠️ 중요한 보안 주의사항

1. **개인키 보안**: 개인키(확장자 없는 파일)는 절대 타인과 공유하지 마세요
2. **즉시 서버 종료**: 키 다운로드 후 즉시 웹서버를 종료하세요 (Ctrl+C)
3. **권한 설정**: 다운로드한 개인키의 권한을 반드시 `600`으로 설정하세요
4. **네트워크 제한**: 가능하면 로컬 네트워크에서만 사용하세요
5. **방화벽 설정**: 필요한 경우 임시 포트에 대한 방화벽 규칙을 설정하세요

### 🛡️ 보안 기능

- **자동 타임아웃**: 지정된 시간 후 웹서버 자동 종료
- **임시 파일 정리**: 스크립트 종료 시 임시 파일 자동 삭제
- **권한 안내**: 올바른 파일 권한 설정 가이드 제공

## 🔧 시스템 요구사항

- **OS**: Ubuntu 18.04 이상
- **Python**: Python 3.x (자동 설치됨)
- **권한**: sudo 권한 필요 (SSH 설치를 위해)
- **네트워크**: 키를 다운로드할 다른 머신에서 접근 가능한 네트워크

## 📊 스크립트 실행 예시

```bash
$ ./setup_ssh.sh my_key 8080 600

=== SSH 키 생성 및 다운로드 서버 시작 ===
키 이름: my_key
포트: 8080
타임아웃: 600초

SSH가 이미 설치되어 있습니다.
SSH 키 생성 완료!
공개키를 authorized_keys에 추가했습니다.
임시 디렉토리: /tmp/tmp.XYZ123
SSH 서비스를 시작합니다...

=== 서버 정보 ===
로컬 IP: 192.168.1.100
공용 IP: 203.0.113.1
SSH 포트: 22

=== 파일 다운로드 서버 시작 ===
다운로드 URL:
  - 개인키: http://192.168.1.100:8080/my_key
  - 공개키: http://192.168.1.100:8080/my_key.pub
  - 웹 인터페이스: http://192.168.1.100:8080/

다른 머신에서 다운로드 명령어:
  wget http://192.168.1.100:8080/my_key
  wget http://192.168.1.100:8080/my_key.pub

서버는 600초 후 자동 종료됩니다.
수동 종료하려면 Ctrl+C를 누르세요.

포트 8080에서 HTTP 서버 시작...
600초 후 자동 종료됩니다.
```

## 🐛 문제 해결

### 포트가 이미 사용 중인 경우
```bash
# 사용 중인 포트 확인
netstat -tuln | grep :8000

# 다른 포트 사용
./setup_ssh.sh id_rsa 8001
```

### SSH 서비스 상태 확인
```bash
# SSH 서비스 상태 확인
sudo systemctl status ssh

# SSH 서비스 재시작
sudo systemctl restart ssh
```

### 방화벽 설정 (필요한 경우)
```bash
# UFW 방화벽에서 임시 포트 허용
sudo ufw allow 8000/tcp

# 사용 후 규칙 삭제
sudo ufw delete allow 8000/tcp
```

### 권한 문제
```bash
# SSH 디렉토리 권한 확인 및 수정
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
chmod 600 ~/.ssh/개인키이름
chmod 644 ~/.ssh/공개키이름.pub
```

## 🤝 기여하기

이슈 리포트나 개선 제안은 언제든 환영합니다!

1. 이 저장소를 Fork하세요
2. 기능 브랜치를 생성하세요 (`git checkout -b feature/AmazingFeature`)
3. 변경사항을 커밋하세요 (`git commit -m 'Add some AmazingFeature'`)
4. 브랜치에 Push하세요 (`git push origin feature/AmazingFeature`)
5. Pull Request를 생성하세요

## 📝 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다. 자세한 내용은 `LICENSE` 파일을 참조하세요.

## ❓ FAQ

### Q: 스크립트가 sudo 권한을 요구하는 이유는?
A: SSH 서버 설치 및 시스템 서비스 관리를 위해 sudo 권한이 필요합니다.

### Q: 웹서버가 자동으로 종료되지 않으면?
A: Ctrl+C를 눌러 수동으로 종료할 수 있습니다. 프로세스가 남아있다면 `pkill -f "python3 server.py"`로 종료하세요.

### Q: 다른 운영체제에서도 사용할 수 있나요?
A: 현재는 Ubuntu/Debian 계열만 지원합니다. 다른 배포판을 위한 수정이 필요할 수 있습니다.

### Q: 키를 여러 번 생성할 수 있나요?
A: 네, 다른 키 이름을 사용하여 여러 개의 키를 생성할 수 있습니다.

## 📞 지원

문제가 발생하면 GitHub Issues를 통해 문의해주세요.

---

⭐ 이 프로젝트가 유용했다면 스타를 눌러주세요!
