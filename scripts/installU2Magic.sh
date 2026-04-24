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

# 解析命令行参数：-p 端口 -v 路径前缀
while getopts "p:v:" opt; do
  case $opt in
    p)
      # 校验端口是否为数字
      if [[ ! $OPTARG =~ ^[0-9]+$ ]]; then
        echo "❌ 错误：端口必须是纯数字！"
        exit 1
      fi
      PORT=$OPTARG
      ;;
    v)
      DATA_PREFIX=$OPTARG
      ;;
    \?)
      echo "❌ 用法：$0 -p 映射端口 -v 数据目录前缀"
      echo "示例：$0 -p 28888 -v /data/u2"
      exit 1
      ;;
  esac
done

# 打印配置信息
echo -e "\n================================================"
echo "📌 容器名称：$CONTAINER_NAME"
echo "📌 映射端口：$PORT:18080"
echo "📌 数据目录：$DATA_PREFIX"
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

# 3. 停止并删除旧容器（避免冲突）
if docker ps -a --format "{{.Names}}" | grep -wq "$CONTAINER_NAME"; then
  echo "🔄 检测到旧容器，正在停止并删除..."
  docker stop $CONTAINER_NAME > /dev/null 2>&1
  docker rm $CONTAINER_NAME > /dev/null 2>&1
fi

# 4. 自动创建数据目录（避免挂载失败）
echo "📂 正在创建数据目录..."
mkdir -p ${DATA_PREFIX}/logs
mkdir -p ${DATA_PREFIX}/data

# 5. 启动容器（核心命令，开启自启动）
echo "🚀 正在启动容器 $CONTAINER_NAME ..."
docker run -d \
  --name $CONTAINER_NAME \
  --restart always \
  -p $PORT:18080 \
  -v ${DATA_PREFIX}/logs:/data/u2Magic/logs \
  -v ${DATA_PREFIX}/data:/data/u2 \
  --add-host=$ADD_HOST \
  $IMAGE_NAME

# 6. 执行结果校验
if [ $? -eq 0 ]; then
  echo -e "\n✅ 容器启动成功！"
  echo "================================================"
  echo "🌐 访问地址：http://服务器IP:$PORT"
  echo "📂 日志目录：${DATA_PREFIX}/logs"
  echo "📂 数据目录：${DATA_PREFIX}/data"
  echo "🔄 自启动状态：已开启（容器随Docker开机自启）"
  echo "================================================"
else
  echo -e "\n❌ 容器启动失败，请检查端口/目录权限！"
  exit 1
fi