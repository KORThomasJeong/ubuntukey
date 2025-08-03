#!/bin/bash

# SSH 키 생성 및 다운로드 스크립트
# 사용법: ./setup_ssh.sh [키_이름] [포트번호]

set -e

# 기본값 설정
KEY_NAME=${1:-"id_rsa"}
PORT=${2:-8000}
TIMEOUT=${3:-300}  # 5분 타임아웃

echo "=== SSH 키 생성 및 다운로드 서버 시작 ==="
echo "키 이름: $KEY_NAME"
echo "포트: $PORT"
echo "타임아웃: ${TIMEOUT}초"
echo

# SSH 설치 확인 및 설치
if ! command -v ssh &> /dev/null; then
    echo "SSH가 설치되어 있지 않습니다. 설치를 시작합니다..."
    sudo apt update
    sudo apt install -y openssh-server openssh-client
    echo "SSH 설치 완료!"
else
    echo "SSH가 이미 설치되어 있습니다."
fi

# Python3 설치 확인
if ! command -v python3 &> /dev/null; then
    echo "Python3가 설치되어 있지 않습니다. 설치를 시작합니다..."
    sudo apt update
    sudo apt install -y python3
    echo "Python3 설치 완료!"
fi

# SSH 디렉토리 생성
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# 기존 키가 있는지 확인
if [[ -f ~/.ssh/$KEY_NAME ]]; then
    echo "경고: ~/.ssh/$KEY_NAME 키가 이미 존재합니다."
    read -p "덮어쓰시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "작업을 취소합니다."
        exit 1
    fi
fi

# SSH 키 생성
echo "SSH 키를 생성합니다..."
ssh-keygen -t rsa -b 4096 -f ~/.ssh/$KEY_NAME -N "" -C "$(whoami)@$(hostname)"
echo "SSH 키 생성 완료!"

# 공개키를 authorized_keys에 추가
if [[ -f ~/.ssh/$KEY_NAME.pub ]]; then
    cat ~/.ssh/$KEY_NAME.pub >> ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys
    echo "공개키를 authorized_keys에 추가했습니다."
fi

# 임시 디렉토리 생성
TEMP_DIR=$(mktemp -d)
echo "임시 디렉토리: $TEMP_DIR"

# 키 파일들을 임시 디렉토리에 복사
cp ~/.ssh/$KEY_NAME $TEMP_DIR/
cp ~/.ssh/$KEY_NAME.pub $TEMP_DIR/

# SSH 서비스 시작
echo "SSH 서비스를 시작합니다..."
sudo systemctl enable ssh
sudo systemctl start ssh

# 현재 IP 주소 확인
LOCAL_IP=$(hostname -I | awk '{print $1}')
PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo "확인불가")

echo
echo "=== 서버 정보 ==="
echo "로컬 IP: $LOCAL_IP"
echo "공용 IP: $PUBLIC_IP"
echo "SSH 포트: 22"
echo

# 포트 사용 중인지 확인
if netstat -tuln | grep ":$PORT " > /dev/null; then
    echo "경고: 포트 $PORT가 이미 사용 중입니다."
    echo "다른 포트를 사용하거나 해당 프로세스를 종료해주세요."
    read -p "계속하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        rm -rf $TEMP_DIR
        exit 1
    fi
fi

# Python 서버 스크립트 생성
cat > $TEMP_DIR/server.py << 'EOF'
#!/usr/bin/env python3
import http.server
import socketserver
import os
import sys
import signal
import threading
import time

class CustomHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, format, *args):
        print(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] {format % args}")
    
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        super().end_headers()

def signal_handler(signum, frame):
    print(f"\n신호 {signum} 수신. 서버를 종료합니다...")
    os._exit(0)

signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)

port = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
timeout = int(sys.argv[2]) if len(sys.argv) > 2 else 300

print(f"포트 {port}에서 HTTP 서버 시작...")
print(f"{timeout}초 후 자동 종료됩니다.")

with socketserver.TCPServer(("", port), CustomHTTPRequestHandler) as httpd:
    def shutdown_server():
        time.sleep(timeout)
        print(f"\n타임아웃 ({timeout}초) 도달. 서버를 종료합니다...")
        httpd.shutdown()
    
    timer = threading.Thread(target=shutdown_server)
    timer.daemon = True
    timer.start()
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n사용자가 서버를 중단했습니다.")
    finally:
        httpd.server_close()
EOF

chmod +x $TEMP_DIR/server.py

# 다운로드 안내 페이지 생성
cat > $TEMP_DIR/index.html << EOF
<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SSH 키 다운로드</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
        .key-info { background: #f5f5f5; padding: 15px; margin: 10px 0; border-radius: 5px; }
        .download-link { display: inline-block; padding: 10px 20px; background: #007bff; color: white; text-decoration: none; border-radius: 5px; margin: 5px; }
        .download-link:hover { background: #0056b3; }
        .warning { background: #fff3cd; border: 1px solid #ffeaa7; padding: 10px; border-radius: 5px; margin: 10px 0; }
        .command { background: #f8f9fa; padding: 10px; border-left: 4px solid #007bff; margin: 10px 0; font-family: monospace; }
    </style>
</head>
<body>
    <h1>SSH 키 다운로드</h1>
    
    <div class="warning">
        <strong>⚠️ 보안 주의사항:</strong>
        <ul>
            <li>개인키는 절대 타인과 공유하지 마세요</li>
            <li>다운로드 후 즉시 이 서버를 종료하세요</li>
            <li>개인키 파일의 권한을 600으로 설정하세요</li>
        </ul>
    </div>

    <div class="key-info">
        <h3>생성된 키 정보</h3>
        <p><strong>키 이름:</strong> $KEY_NAME</p>
        <p><strong>생성 시간:</strong> $(date)</p>
        <p><strong>호스트:</strong> $(whoami)@$(hostname)</p>
    </div>

    <h3>다운로드</h3>
    <a href="$KEY_NAME" class="download-link" download>🔑 개인키 다운로드 ($KEY_NAME)</a>
    <a href="$KEY_NAME.pub" class="download-link" download>🔓 공개키 다운로드 ($KEY_NAME.pub)</a>

    <h3>사용 방법</h3>
    <div class="command">
        # 키 다운로드 (다른 머신에서)<br>
        wget http://$LOCAL_IP:$PORT/$KEY_NAME<br>
        wget http://$LOCAL_IP:$PORT/$KEY_NAME.pub<br><br>
        
        # 또는 curl 사용<br>
        curl -O http://$LOCAL_IP:$PORT/$KEY_NAME<br>
        curl -O http://$LOCAL_IP:$PORT/$KEY_NAME.pub<br><br>
        
        # 권한 설정<br>
        chmod 600 $KEY_NAME<br>
        chmod 644 $KEY_NAME.pub<br><br>
        
        # SSH 연결<br>
        ssh -i $KEY_NAME $(whoami)@$LOCAL_IP
    </div>

    <p><small>이 서버는 ${TIMEOUT}초 후 자동으로 종료됩니다.</small></p>
</body>
</html>
EOF

echo
echo "=== 파일 다운로드 서버 시작 ==="
echo "다운로드 URL:"
echo "  - 개인키: http://$LOCAL_IP:$PORT/$KEY_NAME"
echo "  - 공개키: http://$LOCAL_IP:$PORT/$KEY_NAME.pub"
echo "  - 웹 인터페이스: http://$LOCAL_IP:$PORT/"
echo
echo "다른 머신에서 다운로드 명령어:"
echo "  wget http://$LOCAL_IP:$PORT/$KEY_NAME"
echo "  wget http://$LOCAL_IP:$PORT/$KEY_NAME.pub"
echo
echo "서버는 ${TIMEOUT}초 후 자동 종료됩니다."
echo "수동 종료하려면 Ctrl+C를 누르세요."
echo

# 서버 시작
cd $TEMP_DIR
python3 server.py $PORT $TIMEOUT

# 정리
echo
echo "서버가 종료되었습니다. 임시 파일을 정리합니다..."
cd /
rm -rf $TEMP_DIR

echo
echo "=== 완료 ==="
echo "SSH 키가 ~/.ssh/$KEY_NAME 에 저장되었습니다."
echo "SSH 서비스가 실행 중입니다."
echo
echo "연결 테스트:"
echo "  ssh $(whoami)@localhost"
echo "  ssh -i ~/.ssh/$KEY_NAME $(whoami)@$LOCAL_IP"
echo
