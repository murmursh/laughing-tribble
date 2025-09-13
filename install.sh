apt update && apt upgrade -y
apt install curl git -y
curl -fsSL https://get.docker.com | sh

mkdir remn && cd remn
git clone --depth 1 -b node https://github.com/murmursh/laughing-tribble.git