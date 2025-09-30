#!/bin/bash

# 统一日志函数
log() {
  echo "[App-UIKit] $(date +"%Y-%m-%d %H:%M:%S") > $1"
}

# 初始化路径
ROOT="${WORKSPACE}/client_uikit"
PROJ_PATH="${ROOT}/application/ios/App-UIKit"
PROJ_FILE="${PROJ_PATH}/App-UIKit.xcworkspace"
SDK_PATH="${ROOT}/SDK/iOS/"
export RDM_OUTPUT="${WORKSPACE}/application/ios/result"

pod_install() {
  log "> Procedure: pod update"
  cd "${PROJ_PATH}" || exit 1
  
  log "当前Pod环境:"
  pod --version
  pod repo list
  
  if ! gem install cocoapods --no-document; then
    log "Failed to install CocoaPods"
    exit 1
  fi

  if ! pod repo update --verbose; then
    log "Warning: Pod repo update 失败，尝试继续..."
  fi

  if ! pod install --verbose; then
    log "Failed to run 'pod install'"
    exit 1
  fi
  
  log "Pod 依赖安装完成"
}

#  版本号设置
setup_version() {
  if [ -z "${APP_VER}" ]; then
    APP_VER="${BK_CI_MAJOR_VERSION}.${BK_CI_MINOR_VERSION}.${BK_CI_FIX_VERSION}"
  fi
  
  if [ -z "${APP_BUILD_NO}" ]; then
    APP_BUILD_NO="${BK_CI_BUILD_NO}"
  fi
  
  if [ -z "${VERSION}" ]; then
    VERSION="${APP_VER}.${APP_BUILD_NO}"
  fi
  
  log "APP版本: ${APP_VER}"
  log "构建号: ${APP_BUILD_NO}"
  log "完整版本: ${VERSION}"
}

# 修改Info.plist版本号
fix_info_version() {
  local InfoPath="${PROJ_PATH}/App-UIKit/Info.plist"
  if [ -e "${InfoPath}" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${APP_BUILD_NO}" "${InfoPath}"
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${APP_VER}" "${InfoPath}"
    log "版本号更新成功:"
    /usr/libexec/PlistBuddy -c "Print" "${InfoPath}"
  else
    log "Error: Info.plist 文件不存在于 ${InfoPath}"
    exit 1
  fi
}

# IPA打包
release_ipa() {
  local SCHEME="App-UIKit"
  local tmpdir=$(mktemp -d)
  
  mkdir -p "${RDM_OUTPUT}"
  log "输出目录: ${RDM_OUTPUT}"
  
  log "> 开始归档..."
  xcodebuild archive \
    -workspace "${PROJ_FILE}" \
    -scheme "${SCHEME}" \
    -configuration Release \
    -archivePath "${tmpdir}/${SCHEME}.xcarchive" \
    -derivedDataPath "${ROOT}/build" \
    -allowProvisioningUpdates \
    -destination 'generic/platform=iOS' || {
      log "归档失败"
      exit 1
    }
  
  log "> 开始导出IPA..."
  xcodebuild -exportArchive \
    -archivePath "${tmpdir}/${SCHEME}.xcarchive" \
    -exportOptionsPlist "${ROOT}/application/devops/AppUIKit.plist" \
    -exportPath "${tmpdir}/export" || {
      log "导出IPA失败"
      exit 1
    }
  
  mv "${tmpdir}/export/${SCHEME}.ipa" "${RDM_OUTPUT}/${SCHEME}-${VERSION}.ipa"
  log "IPA生成成功: ${RDM_OUTPUT}/${SCHEME}-${VERSION}.ipa"
  
  pushd "${tmpdir}/${SCHEME}.xcarchive" >/dev/null
  zip -r "${RDM_OUTPUT}/${SCHEME}-${VERSION}-dsyms.zip" dSYMs
  popd >/dev/null

  rm -rf "${tmpdir}"
  rm -rf "${ROOT}/build"

  log "最终生成文件:"
  ls -lh "${RDM_OUTPUT}"
}


main() {
  set -ex

  log "===== 环境检查 ====="
  log "WORKSPACE: ${WORKSPACE}"
  log "当前目录: $(pwd)"
  log "Xcode版本: $(ls /Applications | grep Xcode)"
  
  if [[ ! -e "${WORKSPACE}/application" ]]; then
    ln -sf "${ROOT}/application" "${WORKSPACE}/application"
    log "已创建符号链接: ${WORKSPACE}/application -> ${ROOT}/application"
  fi
  
  pod_install
  setup_version
  fix_info_version
  release_ipa
  
  log "===== 构建成功 ====="
}

main
