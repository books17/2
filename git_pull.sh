#!/usr/bin/env bash
## Author: SuperManito
## Project: JD-FreeFuck
## Modified: 2021-3-7

## 文件路径、脚本网址、文件版本以及各种环境的判断
ShellDir=${JD_DIR:-$(
  cd $(dirname $0)
  pwd
)}
[[ ${JD_DIR} ]] && ShellJd=jd || ShellJd=${ShellDir}/jd.sh
LogDir=${ShellDir}/log
[ ! -d ${LogDir} ] && mkdir -p ${LogDir}
ScriptsDir=${ShellDir}/scripts
ConfigDir=${ShellDir}/config
FileConf=${ConfigDir}/config.sh
FileDiy=${ConfigDir}/diy.sh
FileConfSample=${ShellDir}/sample/config.sh.sample
ListCron=${ConfigDir}/crontab.list
ListCronLxk=${ScriptsDir}/docker/crontab_list.sh
ListTask=${LogDir}/task.list
ListJs=${LogDir}/js.list
ListJsAdd=${LogDir}/js-add.list
ListJsDrop=${LogDir}/js-drop.list
ContentVersion=${ShellDir}/version
ContentNewTask=${ShellDir}/new_task
ContentDropTask=${ShellDir}/drop_task
SendCount=${ShellDir}/send_count
isTermux=${ANDROID_RUNTIME_ROOT}${ANDROID_ROOT}
ScriptsURL=git@gitee.com:lxk0301/jd_scripts.git
DIY_URL=https://gitee.com/SuperManito/JD-FreeFuck/raw/main/diy/diy.sh


## 更新crontab，gitee服务器同一时间限制5个链接，因此每个人更新代码必须错开时间，每次执行git_pull随机生成。
## 每天次数随机，更新时间随机，更新秒数随机，至少6次，至多12次，大部分为8-10次，符合正态分布。
function Update_Cron() {
  if [ -f ${ListCron} ]; then
    RanMin=$((${RANDOM} % 60))
    RanSleep=$((${RANDOM} % 56))
    RanHourArray[0]=$((${RANDOM} % 3))
    for ((i = 1; i < 14; i++)); do
      j=$(($i - 1))
      tmp=$((${RANDOM} % 3 + ${RanHourArray[j]} + 2))
      [[ ${tmp} -lt 24 ]] && RanHourArray[i]=${tmp} || break
    done
    RanHour=${RanHourArray[0]}
    for ((i = 1; i < ${#RanHourArray[*]}; i++)); do
      RanHour="${RanHour},${RanHourArray[i]}"
    done
    perl -i -pe "s|.+(bash git_pull.+)|${RanMin} ${RanHour} \* \* \* sleep ${RanSleep} && \1|" ${ListCron}
    crontab ${ListCron}
  fi
}

## 更新Shell源码
function Git_PullShell {
  echo -e "\n更新 Shell 项目脚本：\n"
  cd ${ShellDir}
  git fetch --all
  ExitStatusShell=$?
  git reset --hard origin/source
}

## 克隆scripts
function Git_CloneScripts() {
  echo -e "\n克隆 lxk0301 活动脚本：\n"
  git clone -b master ${ScriptsURL} ${ScriptsDir}
  ExitStatusScripts=$?
  echo
}

## 更新scripts
function Git_PullScripts() {
  echo -e "\n更新 lxk0301 活动脚本：\n"
  cd ${ScriptsDir}
  git fetch --all
  ExitStatusScripts=$?
  git reset --hard origin/master
  echo
}

## 用户数量UserSum
function Count_UserSum() {
  i=1
  while [ $i -le 1000 ]; do
    Tmp=Cookie$i
    CookieTmp=${!Tmp}
    [[ ${CookieTmp} ]] && UserSum=$i || break
    let i++
  done
}

## 把config.sh中提供的所有账户的PIN附加在jd_joy_run.js中，让各账户相互进行宠汪汪赛跑助力
function Change_JoyRunPins() {
  j=${UserSum}
  PinALL=""
  while [[ $j -ge 1 ]]; do
    Tmp=Cookie$j
    CookieTemp=${!Tmp}
    PinTemp=$(echo ${CookieTemp} | perl -pe "{s|.*pt_pin=(.+);|\1|; s|%|\\\x|g}")
    PinTempFormat=$(printf ${PinTemp})
    PinALL="${PinTempFormat},${PinALL}"
    let j--
  done
  perl -i -pe "{s|(let invite_pins = \[\")(.+\"\];?)|\1${PinALL}\2|; s|(let run_pins = \[\")(.+\"\];?)|\1${PinALL}\2|}" ${ScriptsDir}/jd_joy_run.js
}

## 修改lxk0301大佬js文件的函数汇总
function Change_ALL() {
  if [ -f ${FileConf} ]; then
    . ${FileConf}
    if [ -n "${Cookie1}" ]; then
      Count_UserSum
      Change_JoyRunPins
    fi
  fi
}

## 检测文件：lxk0301/jd_scripts 仓库中的 docker/crontab_list.sh
## 检测定时任务是否有变化，此函数会在Log文件夹下生成四个文件，分别为：
## task.list    crontab.list中的所有任务清单，仅保留脚本名
## js.list      上述检测文件中用来运行js脚本的清单（去掉后缀.js，非运行脚本的不会包括在内）
## js-add.list  如果上述检测文件增加了定时任务，这个文件内容将不为空
## js-drop.list 如果上述检测文件删除了定时任务，这个文件内容将不为空
function Diff_Cron() {
  if [ -f ${ListCron} ]; then
    if [ -n "${JD_DIR}" ]; then
      grep -E " j[drx]_\w+" ${ListCron} | perl -pe "s|.+ (j[drx]_\w+).*|\1|" | sort -u >${ListTask}
    else
      grep "${ShellDir}/" ${ListCron} | grep -E " j[drx]_\w+" | perl -pe "s|.+ (j[drx]_\w+).*|\1|" | sort -u >${ListTask}
    fi

    cat ${ListCronLxk} | grep -E "j[drx]_\w+\.js" | perl -pe "s|.+(j[drx]_\w+)\.js.+|\1|" | sort -u >${ListJs}
    if [[ ${EnableExtraShell} == true ]]; then
      cat ${FileDiy} | grep -v "#" | grep "my_scripts_list" | grep -io "j[drx]_[a-z]*\w[a-z]*" | sort -u >>${ListJs}
    fi

    grep -vwf ${ListTask} ${ListJs} >${ListJsAdd}
    grep -vwf ${ListJs} ${ListTask} >${ListJsDrop}
  else
    echo -e "${ListCron} 文件不存在，请先定义您自己的crontab.list...\n"
  fi
}

## 发送删除失效定时任务的消息
function Notify_DropTask() {
  cd ${ShellDir}
  node update.js
  [ -f ${ContentDropTask} ] && rm -f ${ContentDropTask}
}

## 发送新的定时任务消息
function Notify_NewTask() {
  cd ${ShellDir}
  node update.js
  [ -f ${ContentNewTask} ] && rm -f ${ContentNewTask}
}

## 检测配置文件版本
function Notify_Version() {
  [ -f "${SendCount}" ] && [[ $(cat ${SendCount}) != ${VerConfSample} ]] && rm -f ${SendCount}
  UpdateDate=$(grep " Date: " ${FileConfSample} | awk -F ": " '{print $2}')
  UpdateContent=$(grep " Update Content: " ${FileConfSample} | awk -F ": " '{print $2}')
  if [ -f ${FileConf} ] && [[ "${VerConf}" != "${VerConfSample}" ]] && [[ ${UpdateDate} == $(date "+%Y-%m-%d") ]]; then
    if [ ! -f ${SendCount} ]; then
      echo -e "检测到配置文件config.sh.sample有更新\n\n更新日期: ${UpdateDate}\n当前版本: ${VerConf}\n新的版本: ${VerConfSample}\n更新内容: ${UpdateContent}\n如需使用新功能请对照config.sh.sample，将相关新参数手动增加到您自己的config.sh中，否则请无视本消息。\n" | tee ${ContentVersion}
      echo -e "本消息只在该新版本配置文件更新当天发送一次。" >>${ContentVersion}
      cd ${ShellDir}
      node update.js
      if [ $? -eq 0 ]; then
        echo "${VerConfSample}" >${SendCount}
        [ -f ${ContentVersion} ] && rm -f ${ContentVersion}
      fi
    fi
  else
    [ -f ${ContentVersion} ] && rm -f ${ContentVersion}
    [ -f ${SendCount} ] && rm -f ${SendCount}
  fi
}

## npm install 子程序，判断是否为安卓，判断是否安装有yarn
function Npm_InstallSub() {
  if [ -n "${isTermux}" ]; then
    npm install --no-bin-links || npm install --no-bin-links --registry=https://registry.npm.taobao.org
  elif ! type yarn >/dev/null 2>&1; then
    npm install || npm install --registry=https://registry.npm.taobao.org
  else
    echo -e "检测到本机安装了 yarn，使用 yarn 替代 npm...\n"
    yarn install || yarn install --registry=https://registry.npm.taobao.org
  fi
}

## npm install
function Npm_Install() {
  cd ${ScriptsDir}
  if [[ "${PackageListOld}" != "$(cat package.json)" ]]; then
    echo -e "检测到package.json有变化，运行 npm install...\n"
    Npm_InstallSub
    if [ $? -ne 0 ]; then
      echo -e "\nnpm install 运行不成功，自动删除 ${ScriptsDir}/node_modules 后再次尝试一遍..."
      rm -rf ${ScriptsDir}/node_modules
    fi
    echo
  fi

  if [ ! -d ${ScriptsDir}/node_modules ]; then
    echo -e "运行 npm install...\n"
    Npm_InstallSub
    if [ $? -ne 0 ]; then
      echo -e "\nnpm install 运行不成功，自动删除 ${ScriptsDir}/node_modules...\n"
      echo -e "请进入 ${ScriptsDir} 目录后按照wiki教程手动运行 npm install...\n"
      echo -e "当 npm install 失败时，如果检测到有新任务或失效任务，只会输出日志，不会自动增加或删除定时任务...\n"
      echo -e "3...\n"
      sleep 1
      echo -e "2...\n"
      sleep 1
      echo -e "1...\n"
      sleep 1
      rm -rf ${ScriptsDir}/node_modules
    fi
  fi
}

## 输出是否有新的定时任务
function Output_ListJsAdd() {
  if [ -s ${ListJsAdd} ]; then
    echo -e "检测到有新的定时任务：\n"
    cat ${ListJsAdd}
    echo
  fi
}

## 输出是否有失效的定时任务
function Output_ListJsDrop() {
  if [ ${ExitStatusScripts} -eq 0 ] && [ -s ${ListJsDrop} ]; then
    echo -e "检测到有失效的定时任务：\n"
    cat ${ListJsDrop}
    echo
  fi
}

## 自动删除失效的脚本与定时任务，需要5个条件：1.AutoDelCron 设置为 true；2.正常更新js脚本，没有报错；3.js-drop.list不为空；4.crontab.list存在并且不为空；5.已经正常运行过npm install
## 检测文件：lxk0301/jd_scripts 仓库中的 docker/crontab_list.sh
## 如果检测到某个定时任务在上述检测文件中已删除，那么在本地也删除对应定时任务
function Del_Cron() {
  if [ "${AutoDelCron}" = "true" ] && [ -s ${ListJsDrop} ] && [ -s ${ListCron} ] && [ -d ${ScriptsDir}/node_modules ]; then
    echo -e "开始尝试自动删除定时任务如下：\n"
    cat ${ListJsDrop}
    echo
    JsDrop=$(cat ${ListJsDrop})
    for Cron in ${JsDrop}; do
      perl -i -ne "{print unless / ${Cron}( |$)/}" ${ListCron}
    done
    crontab ${ListCron}
    echo -e "成功删除失效的脚本与定时任务，当前的定时任务清单如下：\n\n--------------------------------------------------------------\n"
    crontab -l
    echo -e "\n--------------------------------------------------------------\n"
    if [ -d ${ScriptsDir}/node_modules ]; then
      echo -e "删除失效的定时任务：\n\n${JsDrop}" >${ContentDropTask}
      Notify_DropTask
    fi
  fi
}

## 自动增加新的定时任务，需要5个条件：1.AutoAddCron 设置为 true；2.正常更新js脚本，没有报错；3.js-add.list不为空；4.crontab.list存在并且不为空；5.已经正常运行过npm install
## 检测文件：lxk0301/jd_scripts 仓库中的 docker/crontab_list.sh
## 如果检测到检测文件中增加新的定时任务，那么在本地也增加
## 本功能生效时，会自动从检测文件新增加的任务中读取时间，该时间为北京时间
function Add_Cron() {
  if [ "${AutoAddCron}" = "true" ] && [ -s ${ListJsAdd} ] && [ -s ${ListCron} ] && [ -d ${ScriptsDir}/node_modules ]; then
    echo -e "开始尝试自动添加定时任务如下：\n"
    cat ${ListJsAdd}
    echo
    JsAdd=$(cat ${ListJsAdd})

    for Cron in ${JsAdd}; do
      if [[ ${Cron} == jd_bean_sign ]]; then
        echo "4 0,9 * * * bash ${ShellJd} ${Cron}" >>${ListCron}
      else
        cat ${ListCronLxk} | grep -E "\/${Cron}\." | perl -pe "s|(^.+)node */scripts/(j[drx]_\w+)\.js.+|\1bash ${ShellJd} \2|" >>${ListCron}
      fi
    done

    if [ $? -eq 0 ]; then
      crontab ${ListCron}
      echo -e "成功添加新的定时任务，当前的定时任务清单如下：\n\n--------------------------------------------------------------\n"
      crontab -l
      echo -e "\n--------------------------------------------------------------\n"
      if [ -d ${ScriptsDir}/node_modules ]; then
        echo -e "成功添加新的定时任务：\n\n${JsAdd}" >${ContentNewTask}
        Notify_NewTask
      fi
    else
      echo -e "添加新的定时任务出错，请手动添加...\n"
      if [ -d ${ScriptsDir}/node_modules ]; then
        echo -e "尝试自动添加以下新的定时任务出错，请手动添加：\n\n${JsAdd}" >${ContentNewTask}
        Notify_NewTask
      fi
    fi
  fi
}

## 自定义脚本功能
function ExtraShell() {
  ## 自动同步用户自定义的diy.sh
  if [[ ${EnableExtraShellUpdate} == true ]]; then
    wget -q $DIY_URL -O ${ShellDir}/config/diy.sh
    if [ $? -eq 0 ]; then
      echo -e "自定义 DIY 脚本同步完成......"
      echo -e ''
      sleep 2s
    else
      echo -e "自定义 DIY 脚本同步失败......"
      echo -e ''
      sleep 2s
    fi
  fi

  ## 调用用户自定义的diy.sh
  if [[ ${EnableExtraShell} == true ]]; then
    if [ -f ${FileDiy} ]; then
      . ${FileDiy}
    else
      echo -e "${FileDiy} 文件不存在，跳过执行自定义 DIY 脚本...\n"
      echo -e ''
    fi
  fi
}

## 一键执行所有活动脚本
function RUN_ALL() {
  ## 默认将 "jd、jx、jr" 开头的活动脚本加入其中
  rm -rf ${ShellDir}/run-all.sh
  bash ${ShellDir}/jd.sh | grep -io 'j[drx]_[a-z].*' | grep -v 'bean_change' >${ShellDir}/run-all.sh
  sed -i "1i\jd_bean_change.js" ${ShellDir}/run-all.sh ## 置顶京豆变动通知
  sed -i "s#^#bash ${ShellDir}/jd.sh &#g" ${ShellDir}/run-all.sh
  sed -i 's#.js# now#g' ${ShellDir}/run-all.sh
  sed -i '1i\#!/bin/env bash' ${ShellDir}/run-all.sh
  ## 自定义添加脚本
  ## 例：echo "bash ${ShellDir}/jd.sh xxx now" >>${ShellDir}/run-all.sh

  ## 将挂机活动移至末尾从而最后执行
  ## 目前仅有 "疯狂的JOY" 这一个活动
  ## 模板如下 ：
  ## cat run-all.sh | grep xxx -wq
  ## if [ $? -eq 0 ];then
  ##   sed -i '/xxx/d' ${ShellDir}/run-all.sh
  ##   echo "bash jd.sh xxx now" >>${ShellDir}/run-all.sh
  ## fi
  cat ${ShellDir}/run-all.sh | grep jd_crazy_joy_coin -wq
  if [ $? -eq 0 ]; then
    sed -i '/jd_crazy_joy_coin/d' ${ShellDir}/run-all.sh
    echo "bash ${ShellDir}/jd.sh jd_crazy_joy_coin now" >>${ShellDir}/run-all.sh
  fi

  ## 去除不想加入到此脚本中的活动
  ## 例：sed -i '/xxx/d' ${ShellDir}/run-all.sh
  sed -i '/jd_delCoupon/d' ${ShellDir}/run-all.sh ## 不执行 "京东家庭号" 活动
  sed -i '/jd_family/d' ${ShellDir}/run-all.sh    ## 不执行 "删除优惠券" 活动

  ## 去除脚本中的空行
  sed -i '/^\s*$/d' ${ShellDir}/run-all.sh
  ## 赋权
  chmod 777 ${ShellDir}/run-all.sh
}

## 在日志中记录时间与路径
echo -e ''
echo -e "-----------------------------------------------"
echo -e ''
echo -e "        当前系统时间：$(date "+%Y-%m-%d %H:%M")"
echo -e ''
echo -e "        活动脚本目录：${ScriptsDir}"
echo -e ''
echo -e "-----------------------------------------------"

## 更新crontab
[[ $(date "+%-H") -le 2 ]] && Update_Cron

## 更新Shell源码
[ -d ${ShellDir}/.git ] && Git_PullShell


## 克隆或更新js脚本
[ -f ${ScriptsDir}/package.json ] && PackageListOld=$(cat ${ScriptsDir}/package.json)
[ -d ${ScriptsDir}/.git ] && Git_PullScripts || Git_CloneScripts
echo -e "-----------------------------------------------"
echo -e ''

## 执行各函数
if [[ ${ExitStatusScripts} -eq 0 ]]; then
  Change_ALL
  [ -d ${ScriptsDir}/node_modules ] && Notify_Version
  Diff_Cron
  Npm_Install
  Output_ListJsAdd
  Output_ListJsDrop
  Del_Cron
  Add_Cron
  ExtraShell
  RUN_ALL
  echo -e "活动脚本更新完成......\n"
else
  echo -e "活动脚本更新失败，请检查原因或再次运行 git_pull.sh ......\n"
  Change_ALL
fi
