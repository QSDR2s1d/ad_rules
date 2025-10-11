
#!/bin/sh
set -euo pipefail

# 设置区域变量为 C
LC_ALL='C'

# 清理当前目录下所有 .txt 文件（建议确保脚本工作目录正确）
rm -f *.txt

echo "创建临时文件夹..."
mkdir -p ./tmp/

# 添加补充规则（建议检查源文件是否存在）
cp -f ./data/rules/adblock.txt ./tmp/rules01.txt
cp -f ./data/rules/whitelist.txt ./tmp/allow01.txt

cd tmp

# 规则下载
echo "开始下载规则..."

# 定义下载链接数组（规则和白名单分别处理）
rules=(
  "https://raw.githubusercontent.com/217heidai/adblockfilters/main/rules/adblockdns.txt" #217heidai dns
  "https://raw.githubusercontent.com/217heidai/adblockfilters/main/rules/adblockfilters.txt" #217heidai filter
  "https://raw.githubusercontent.com/Lynricsy/HyperADRules/master/rules.txt" #hyperad filter
  "https://raw.githubusercontent.com/Lynricsy/HyperADRules/master/dns.txt" #hyperad dns
  "https://raw.githubusercontent.com/afwfv/DD-AD/main/rule/DD-AD.txt" #dd-ad
  "https://raw.githubusercontent.com/qq5460168/666/master/dns.txt" #那个谁520 dns
  "http://rssv.cn/adguard/api.php?type=black" #晴雅规则
  "https://filter.futa.gg/hosts_abp.txt" #LowTechHost
  "https://filter.futa.gg/TW165_abp.txt" #TW165台灣反詐騙
  "https://raw.githubusercontent.com/hoshsadiq/adblock-nocoin-list/master/nocoin.txt" #NoCoin Filter List
  "https://raw.githubusercontent.com/hululu1068/AdGuard-Rule/main/rule/mylist.txt" #hululu1068
  "https://www.i-dont-care-about-cookies.eu/abp/" #I don't care about cookies
  "https://raw.githubusercontent.com/Cats-Team/AdRules/main/adblock_plus.txt" #Cats-Team rules
  "https://raw.githubusercontent.com/Cats-Team/AdRules/main/dns.txt" #Cats-Team dns
)

allow=(
  "https://raw.githubusercontent.com/qq5460168/dangchu/main/white.txt"
  "https://raw.githubusercontent.com/mphin/AdGuardHomeRules/main/Allowlist.txt"
  "https://file-git.trli.club/file-hosts/allow/Domains" #冷漠
  "https://raw.githubusercontent.com/user001235/112/main/white.txt" #浅笑
  "https://raw.githubusercontent.com/jhsvip/ADRuls/main/white.txt" #jhsvip
  "https://raw.githubusercontent.com/liwenjie119/adg-rules/master/white.txt" #liwenjie119
  "https://raw.githubusercontent.com/miaoermua/AdguardFilter/main/whitelist.txt" #喵二白名单
  "https://raw.githubusercontent.com/Zisbusy/AdGuardHome-Rules/refs/heads/main/Rules/whitelist.txt" #Zisbusy
  "https://raw.githubusercontent.com/Kuroba-Sayuki/FuLing-AdRules/refs/heads/main/FuLingRules/FuLingAllowList.txt" #茯苓
  "https://raw.githubusercontent.com/urkbio/adguardhomefilter/main/whitelist.txt" #酷安cocieto
  "https://raw.githubusercontent.com/Lynricsy/HyperADRules/master/allow.txt" #hyperad allow
  "https://raw.githubusercontent.com/qq5460168/666/refs/heads/master/allow.txt" #那个谁520 allow
  "https://raw.githubusercontent.com/privacy-protection-tools/dead-horse/master/anti-ad-white-list.txt" #anti-ad allow
)

# 使用并发curl下载规则和白名单，并通过 iconv 转码后存入文件
for i in "${!rules[@]}"; do
  url="${rules[$i]}"
  [ -z "$url" ] && continue
  curl -m 60 --retry-delay 2 --retry 5 --parallel --parallel-immediate -k -L -C - --connect-timeout 60 -s "$url" | iconv -t utf-8 > "rules${i}.txt" &
done

for i in "${!allow[@]}"; do
  url="${allow[$i]}"
  [ -z "$url" ] && continue
  curl -m 60 --retry-delay 2 --retry 5 --parallel --parallel-immediate -k -L -C - --connect-timeout 60 -s "$url" | iconv -t utf-8 > "allow${i}.txt" &
done

wait
echo "规则下载完成"

# 为下载的每个文件添加空行结束（防止因末尾无换行导致处理错误）
for f in $(ls *.txt | sort -u); do
  echo "" >> "$f" &
done
wait

echo "开始处理规则"

# 提取处理规则：过滤空行、注释、IP格式不符合要求的行，并转换部分地址格式，然后排序去重
cat *.txt | sort -n | grep -v -E "^((#.*)|(\s*))$" \
  | grep -v -E "^[0-9f\.:]+\s+(ip6\-)|(localhost|local|loopback)$" \
  | grep -Ev "local.*\.local.*$" \
  | sed 's/127.0.0.1/0.0.0.0/g' | sed 's/::/0.0.0.0/g' \
  | grep '0.0.0.0' | grep -Ev '.0.0.0.0 ' \
  | sort | uniq > base-src-hosts.txt
wait

echo "开始合并规则..."

# 合并规则：过滤掉注释行、空行，并对 AdGuard 规则进行去重
cat rules*.txt | grep -Ev "^(#|!|\[)" | sed '/^$/d' | sort -u > tmp-rules.txt &

# 从所有规则中提取允许域名（以 @@|| 开头，或以 || 开头的规则）
cat *.txt | grep '^@@||.*\^$' | sort -u > allow_ends_with_caret.txt
cat *.txt | grep '^@@||.*\^\$important$' | sort -u > allow_ends_with_important.txt

# 合并两种允许规则
cat allow_ends_with_caret.txt allow_ends_with_important.txt | sort -u > tmp-allow.txt
wait

# 移动合并后的规则到上级目录
cp tmp-allow.txt ../allow.txt
cp tmp-rules.txt ../rules.txt

echo "规则合并完成"

# 调用 Python 脚本进一步处理重复规则、过滤规则和添加标题
python ../data/python/rule.py
python ../data/python/filter-dns.py
python ../data/python/whitelist.py 

# 添加标题和日期
python ../data/python/title.py

wait
echo "更新成功"

exit 0
