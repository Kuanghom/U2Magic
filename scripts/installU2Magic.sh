#!/bin/bash
# ==================== 配置项（可自行修改）====================
# 默认映射端口（未指定 -p 时使用）
DEFAULT_PORT=18080
# 默认数据目录前缀（未指定 -v 时使用）
DEFAULT_DATA_PREFIX=/data/docker/u2
# 容器名称
CONTAINER_NAME=u2magic
# 镜像地址
IMAGE_NAME=kuanghom/u2magic:latest
# 固定host映射（无需修改）
ADD_HOST=u2.dmhy.org:104.25.27.31
# ==========================================================

# 初始化变量
PORT=$DEFAULT_PORT
DATA_PREFIX=$DEFAULT_DATA_PREFIX
TOKEN=""

# 生成16位随机字母数字token
generate_random_token() {
  echo $(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 16)
}

# 解析命令行参数：-p 端口 -v 路径前缀 -t 自定义token
while getopts "p:v:t:" opt; do
  case $opt in
    p)
      # 校验端口是否为纯数字
      if [[ ! $OPTARG =~ ^[0-9]+$ ]]; then
        echo "❌ 错误：端口必须是纯数字！"
        exit 1
      fi
      PORT=$OPTARG
      ;;
    v)
      DATA_PREFIX=$OPTARG
      ;;
    t)
      TOKEN=$OPTARG
      ;;
    \?)
      echo "❌ 用法：$0 -p 映射端口 -v 数据目录前缀 -t 自定义token"
      echo "示例1：$0 -p 28888 -v /data/u2 -t mytoken123456"
      echo "示例2：$0 -p 28888 -v /data/u2  (自动生成16位token)"
      exit 1
      ;;
  esac
done

# 未指定-t参数，自动生成16位随机token
if [ -z "$TOKEN" ]; then
  TOKEN=$(generate_random_token)
  echo "⚠️  未指定token，自动生成16位随机token：$TOKEN"
fi

# ==================== 自动获取服务器真实内网IP ====================
get_local_ip() {
  local ip=$(hostname -I | awk '{print $1}')
  if [ -z "$ip" ]; then
    ip="127.0.0.1"
  fi
  echo "$ip"
}
LOCAL_IP=$(get_local_ip)
# ================================================================

# 打印配置信息
echo -e "\n================================================"
echo "📌 容器名称：$CONTAINER_NAME"
echo "📌 映射端口：$PORT:18080"
echo "📌 数据目录：$DATA_PREFIX"
echo "📌 登录 Token：$TOKEN"
echo "📌 容器镜像：$IMAGE_NAME"
echo -e "================================================\n"

# 1. 检查 Docker 是否安装
if ! command -v docker &> /dev/null; then
  echo "❌ 错误：未检测到 Docker，请先安装 Docker！"
  exit 1
fi

# 2. 检查 Docker 服务是否运行
if ! systemctl is-active --quiet docker; then
  echo "⚠️  Docker 服务未运行，正在启动..."
  systemctl start docker
  if [ $? -ne 0 ]; then
    echo "❌ Docker 启动失败，请检查！"
    exit 1
  fi
fi

# 3. 停止并删除旧容器
if docker ps -a --format "{{.Names}}" | grep -wq "$CONTAINER_NAME"; then
  echo "🔄 检测到旧容器，正在停止并删除..."
  docker stop $CONTAINER_NAME > /dev/null 2>&1
  docker rm $CONTAINER_NAME > /dev/null 2>&1
fi

# 4. 自动创建配置目录
echo "📂 正在创建数据目录..."
mkdir -p ${DATA_PREFIX}/logs
mkdir -p ${DATA_PREFIX}/data
mkdir -p ${DATA_PREFIX}/config

# 5. 生成配置文件 application-base.yml
CONFIG_FILE=${DATA_PREFIX}/config/application-base.yml
echo "📄 生成配置文件：$CONFIG_FILE"
cat > $CONFIG_FILE << EOF
khc:
  web:
    sign-token: ${TOKEN}
EOF

# 6. 启动容器（【已修改】单文件挂载配置）
echo "🚀 正在启动容器 $CONTAINER_NAME ..."
docker run -d \
  --name $CONTAINER_NAME \
  --restart always \
  -p $PORT:18080 \
  -v ${DATA_PREFIX}/logs:/data/u2Magic/logs \
  -v ${DATA_PREFIX}/data:/data/u2 \
  -v ${DATA_PREFIX}/config/application-base.yml:/data/u2Magic/config/application-base.yml \
  --add-host=$ADD_HOST \
  $IMAGE_NAME

# 7. 执行结果校验 + 打印完整信息
if [ $? -eq 0 ]; then
  echo -e "\n✅ 容器启动成功！"
  echo "================================================"
  echo "🌐 配置地址：http://$LOCAL_IP:$PORT/index.html?token=$TOKEN"
  echo "🌐 手动上车地址：http://$LOCAL_IP:$PORT/addTorrent.html?token=$TOKEN"
  echo "🌐 全局token配置地址：http://$LOCAL_IP:$PORT/token.html"
  echo "🔑 登录 Token：$TOKEN"
  echo "📂 配置文件：$CONFIG_FILE"
  echo "📂 日志目录：${DATA_PREFIX}/logs"
  echo "📂 数据目录：${DATA_PREFIX}/data"
  echo "🔄 自启动状态：已开启（开机自动启动）"
  echo "📜 【实时查看日志】日志查看: tail -f ${DATA_PREFIX}/logs/u2magic.log"
  echo "📜 【查看最近100行日志】日志查看: tail -100f ${DATA_PREFIX}/logs/u2magic.log"
  echo "================================================"
else
  echo -e "\n❌ 容器启动失败，请检查端口/目录权限！"
  exit 1
fi