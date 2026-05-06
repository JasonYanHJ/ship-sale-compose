#!/bin/bash

# 默认值
ENV="dev"
EXPORT_DIR="."
TARGET_MONTH=""

# 帮助信息
usage() {
    echo "用法: $0 -m YYYY-MM [-e dev|prod] [-o ./output_path]"
    echo "选项:"
    echo "  -m : 目标月份 (必填, 格式: YYYY-MM)"
    echo "  -e : 环境选择 (可选, 默认为 dev)"
    echo "  -o : 输出目录 (可选, 默认为当前目录)"
    exit 1
}

# 1. 解析命令行参数
while getopts "m:e:o:h" opt; do
    case "$opt" in
        m) TARGET_MONTH=$OPTARG ;;
        e) ENV=$OPTARG ;;
        o) EXPORT_DIR=$OPTARG ;;
        h) usage ;;
        *) usage ;;
    esac
done

# 检查必填项
if [ -z "$TARGET_MONTH" ]; then
    echo "错误: 必须指定目标月份 (-m)"
    usage
fi

# 2. 环境加载与配置
if [ -f .env ]; then
    set -a; source .env; set +a
    echo "已加载 .env 环境变量"
else
    echo "警告: 未找到 .env 文件"
fi

# 动态确定容器名称
if [ "$ENV" == "prod" ]; then
    CONTAINER_NAME="ship-sale-prod-db-1"
else
    CONTAINER_NAME="ship-sale-dev-db-1"
fi

# 检查输出目录
mkdir -p "$EXPORT_DIR"

# 3. 日期逻辑处理
TIMESTAMP=$(date +"%Y%m%d%H%M%S")
START_DATE="${TARGET_MONTH}-01 00:00:00"
OS_TYPE=$(uname -s)

if [ "$OS_TYPE" == "Darwin" ]; then
    END_DATE=$(date -j -v+1m -f "%Y-%m-%d %H:%M:%S" "$START_DATE" "+%Y-%m-%d 00:00:00")
    FILE_PREFIX=$(date -j -f "%Y-%m-%d %H:%M:%S" "$START_DATE" "+%Y%m")_$TIMESTAMP
else
    END_DATE=$(date -d "$START_DATE + 1 month" "+%Y-%m-%d 00:00:00")
    FILE_PREFIX=$(date -d "$START_DATE" "+%Y%m")_$TIMESTAMP
fi

echo "------------------------------------------"
echo "系统环境: $OS_TYPE"
echo "目标环境: $ENV (容器: $CONTAINER_NAME)"
echo "导出区间: $START_DATE 至 $END_DATE"
echo "保存路径: $EXPORT_DIR"
echo "文件前缀: $FILE_PREFIX"
echo "------------------------------------------"

# 4. 执行导出任务
# 定义完整的文件路径
SQL_EMAILS="${EXPORT_DIR}/${FILE_PREFIX}_emails.sql"
SQL_FORWARDS="${EXPORT_DIR}/${FILE_PREFIX}_forwards.sql"
SQL_ATTACHMENTS="${EXPORT_DIR}/${FILE_PREFIX}_attachments.sql"

# 基础 mysqldump 命令 (减少冗余)
DUMP_CMD="docker exec -i $CONTAINER_NAME mysqldump --single-transaction -u root -p${DB_PASSWORD} ${DB_DATABASE}"

echo ">> 正在导出主表..."
$DUMP_CMD emails --where="date_sent >= '$START_DATE' AND date_sent < '$END_DATE'" > "$SQL_EMAILS"

echo ">> 正在导出转发记录..."
$DUMP_CMD email_forwards --where="email_id IN (SELECT id FROM emails WHERE date_sent >= '$START_DATE' AND date_sent < '$END_DATE')" > "$SQL_FORWARDS"

echo ">> 正在导出附件表..."
$DUMP_CMD attachments --where="email_id IN (SELECT id FROM emails WHERE date_sent >= '$START_DATE' AND date_sent < '$END_DATE')" > "$SQL_ATTACHMENTS"

# 5. 删除目标月份的数据
echo ">> 正在删除目标月份的数据..."
DELETE_CMD="docker exec -i $CONTAINER_NAME mysql -u root -p${DB_PASSWORD} ${DB_DATABASE} -e"

$DELETE_CMD "DELETE FROM emails WHERE date_sent >= '$START_DATE' AND date_sent < '$END_DATE';"

echo "------------------------------------------"
echo "数据导出并删除完成！"
ls -lh "$EXPORT_DIR/${FILE_PREFIX}"_*.sql