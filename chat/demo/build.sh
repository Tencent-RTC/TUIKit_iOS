#!/usr/bin/env bash

export LANG="zh_CN.UTF-8"
export LC_ALL="zh_CN.UTF-8"

# 蓝盾默认变量
MajorVersion=${MajorVersion-0}
MinorVersion=${MinorVersion-0}
FixVersion=${FixVersion-0}
BuildNo=${BuildNo-0}

# 蓝盾自定义变量：是否构建 App Store 上架包（参考 imsdk/rdm/ios/build_with_gn.sh 的 AppStore 分支）
BUILD_APP_STORE=${BUILD_APP_STORE-false}

######################## 1、变量赋值 ########################
export SDK_VERSION=${MajorVersion}.${MinorVersion}.${BuildNo}
echo "-------------------- Build Info --------------------"
echo "SDK Version=${SDK_VERSION}"

SHELL_DIR=$(
    cd $(dirname $0)
    pwd
)
BUILD_DIR=${SHELL_DIR}/build

export OUTPUT_DIR=${SHELL_DIR}/../../../../../bin
export SYMBOLS_DIR=${OUTPUT_DIR}/symbols_ios_${SDK_VERSION}
DEMO_BUILD_DIR=${BUILD_DIR}/Build/Products

WORKSPACE_NAME="ChatDemo"
SCHEME_NAME="ChatDemo"
APP_NAME="ChatDemo"
CHATDEMO_PLIST_PATH=${SHELL_DIR}/ChatDemo/Configuration/Info.plist
APPEX_PLIST_PATH=${SHELL_DIR}/pushservice/Info.plist

# App 上架标准版本（CFBundleShortVersionString）与构建号（CFBundleVersion）
# 版本号最后一段与 BuildNo 保持一致（如 9.1.6989）
APP_VERSION=${MajorVersion}.${MinorVersion}.${BuildNo}
APP_BUILD_NO=${BuildNo}

# 上架包应用身份信息：本工程是旧 TUIKitDemo_Swift 上架产物（腾讯云IM）的后续版本，需保持一致
APPSTORE_APP_NAME="TIMChat_AppStore"
APPSTORE_BUNDLE_NAME="TIMChat"
APPSTORE_BUNDLE_ID="com.imchat.imchat"
APPSTORE_DISPLAY_NAME="云通信IM"
APPSTORE_TEAM_ID="FN2V63AD2J"
APPSTORE_PROFILE="com.imchat.imchat_Production_SignProvision"
APPSTORE_APPEX_BUNDLE_ID="com.imchat.imchat.pushservice"
APPSTORE_APPEX_PROFILE="com.imchat.imchat.pushservice_Production_SignProvision"
PBXPROJ_PATH=${SHELL_DIR}/ChatDemo.xcodeproj/project.pbxproj

# 获取编译工具 xcodebuild
BUILD_BIN=$XCODE_PATH$compileEnv
if [[ "${BUILD_BIN}" = "" ]]; then
    BUILD_BIN=xcodebuild
fi

# 获取 xcode 编译版本
BUILD_SDK_VERSION=$(${BUILD_BIN} -showsdks | grep iphoneos | sort -r | head -n 1 | grep -o '[0-9]*\.[0-9]*$')
if [[ ${BUILD_SDK_VERSION} = "" ]]; then
    echo "Error: No iPhone SDK ..."
    exit 1
fi

BUILD_SDK_IPHONEOS="iphoneos${BUILD_SDK_VERSION}"
echo "Build System -> ${BUILD_SDK_IPHONEOS}"

######################## 2、函数定义 ########################

# 前置检查：TUICallKit_Swift 必须为本仓库源码（Podfile 以 :path 引用）；
# RTCRoomEngine/AtomicXCore 统一使用远端已发布版本，无需检出 tuikit_engine。
function checkLocalDependencies() {
    if [[ -f "${SHELL_DIR}/../../call/TUICallKit_Swift.podspec" ]]; then
        echo "Found TUICallKit_Swift source dependency (in-repo)"
    else
        echo "Error: ios/chat/call/TUICallKit_Swift.podspec not found."
        exit 1
    fi
}

# 清理并重新安装 CocoaPods
function cleanAndInstallPods() {
    echo "Cleaning and reinstalling CocoaPods..."
    cd ${SHELL_DIR}

    rm -rf Pods/
    rm -rf ${WORKSPACE_NAME}.xcworkspace
    rm -f Podfile.lock

    echo "Cleaning CocoaPods cache..."
    pod cache clean --all > /dev/null 2>&1 || true

    echo "Installing pods with verbose output..."
    pod install --repo-update --verbose

    if [[ $? -ne 0 ]]; then
        echo "pod install failed !!! "
        echo "Attempting pod install without repo update..."
        pod install --verbose
        if [[ $? -ne 0 ]]; then
            echo "pod install still failed, exiting..."
            exit 1
        fi
    fi

    echo "pod install success !!!"
}

function buildChatDemo() {
    echo ">>>>>>>>> build ${SCHEME_NAME} begin !!! "

    # 清理并重新安装 pods
    cleanAndInstallPods

    # 清理构建目录，避免多次构建 demo，脏数据影响签名
    rm -rf ${DEMO_BUILD_DIR}/*

    # 签名兜底：构建机未安装 Wildcard_202608 描述文件时关闭签名，
    # 保证编译与 ipa 打包不被签名阻断（该产物不可装机，仅供 CI 编译验证）；
    # 构建机已安装描述文件时正常走 Manual 签名（与旧 demo CI 行为一致）。
    SIGNING_OVERRIDES=""
    PROFILE_DIR="${HOME}/Library/MobileDevice/Provisioning Profiles"
    if ! grep -rqsa "Wildcard_202608" "${PROFILE_DIR}" 2>/dev/null; then
        echo "Warning: Provisioning profile 'Wildcard_202608' not found, building with CODE_SIGNING_ALLOWED=NO"
        SIGNING_OVERRIDES="CODE_SIGNING_ALLOWED=NO"
    fi

    ${BUILD_BIN} -workspace ${WORKSPACE_NAME}.xcworkspace -scheme ${SCHEME_NAME} -configuration Release -sdk ${BUILD_SDK_IPHONEOS} -derivedDataPath ${BUILD_DIR} ${SIGNING_OVERRIDES}

    if [[ $? -ne 0 ]]; then
        echo "build iphoneos ${SCHEME_NAME} failed !!! "
        exit 1
    else
        echo "build iphoneos ${SCHEME_NAME} success !!!"
    fi

    # 压缩 Payload 生成 ipa
    echo "zip ${APP_NAME}.ipa"
    mkdir ${DEMO_BUILD_DIR}/Release-iphoneos/Payload
    cp -R ${DEMO_BUILD_DIR}/Release-iphoneos/${APP_NAME}.app ${DEMO_BUILD_DIR}/Release-iphoneos/Payload
    cd ${DEMO_BUILD_DIR}/Release-iphoneos
    zip -r -q ${OUTPUT_DIR}/${APP_NAME}_${SDK_VERSION}.ipa Payload
    rm -rf ${DEMO_BUILD_DIR}/Release-iphoneos/Payload

    # 复制当前版本的符号表
    echo "copy ${APP_NAME} dSYM"
    cp -rf ${DEMO_BUILD_DIR}/Release-iphoneos/${APP_NAME}.app.dSYM ${SYMBOLS_DIR}/
}

# xcodebuild 命令行的 PRODUCT_BUNDLE_IDENTIFIER / PROVISIONING_PROFILE_SPECIFIER 覆盖会作用于
# 所有 target（含 pushservice 扩展），导致扩展与主包 bundle id 相同、扩展描述文件错误，
# 上架校验与安装都会失败。改为按 target 修补 pbxproj 的 Release 配置，编译完成后恢复。
function patchPbxprojForAppStore() {
    cp "${PBXPROJ_PATH}" "${PBXPROJ_PATH}.appstore.backup"
    awk -v appId="${APPSTORE_BUNDLE_ID}" -v appexId="${APPSTORE_APPEX_BUNDLE_ID}" \
        -v appProfile="${APPSTORE_PROFILE}" -v appexProfile="${APPSTORE_APPEX_PROFILE}" \
        -v appBuildNo="${APP_BUILD_NO}" -v appVersion="${APP_VERSION}" '
    {
        if (index($0, "CURRENT_PROJECT_VERSION = ") > 0) {
            sub(/= [^;]+;/, "= " appBuildNo ";")
        } else if (index($0, "MARKETING_VERSION = ") > 0) {
            sub(/= [^;]+;/, "= " appVersion ";")
        } else if (index($0, "CODE_SIGN_ENTITLEMENTS = \"ChatDemo/Configuration/ChatDemo-Release.entitlements\";") > 0) {
            sub("ChatDemo/Configuration/ChatDemo-Release.entitlements", "ChatDemo/Configuration/ChatDemo-AppStore.entitlements")
        } else if (index($0, "CODE_SIGN_ENTITLEMENTS = pushservice/pushserviceRelease.entitlements;") > 0) {
            sub("pushservice/pushserviceRelease.entitlements", "pushservice/pushserviceAppStore.entitlements")
        } else if (index($0, "PRODUCT_BUNDLE_IDENTIFIER = com.imchat.imchat.uikit.pushservice;") > 0) {
            sub("com.imchat.imchat.uikit.pushservice", appexId)
            pending = "appex"
        } else if (index($0, "PRODUCT_BUNDLE_IDENTIFIER = com.imchat.imchat.uikit;") > 0) {
            sub("com.imchat.imchat.uikit", appId)
            pending = "app"
        } else if (pending != "" && index($0, "PROVISIONING_PROFILE_SPECIFIER[sdk=iphoneos*]") > 0) {
            if (pending == "app") {
                sub(/= [^;]+;/, "= " appProfile ";")
            } else {
                sub(/= [^;]+;/, "= " appexProfile ";")
            }
            pending = ""
        }
        print
    }' "${PBXPROJ_PATH}" > "${PBXPROJ_PATH}.tmp" && mv "${PBXPROJ_PATH}.tmp" "${PBXPROJ_PATH}"
}

function restorePbxproj() {
    if [ -f "${PBXPROJ_PATH}.appstore.backup" ]; then
        mv "${PBXPROJ_PATH}.appstore.backup" "${PBXPROJ_PATH}"
    fi
}

# 编译 App Store 上架包（参考 imsdk/rdm/ios/build_with_gn.sh 的 AppStore 分支，
# 应用身份信息与旧 TUIKitDemo_Swift 上架产物「腾讯云IM」保持一致）
function buildAppStoreIpa() {
    echo ">>>>>>>>> build ${APPSTORE_APP_NAME} (App Store) begin !!! "

    # 清理并重新安装 pods
    cleanAndInstallPods

    # 清理构建目录，避免多次构建 demo，脏数据影响签名
    rm -rf ${DEMO_BUILD_DIR}/*

    # 上架包必须使用 Production 描述文件签名，缺失则直接失败（不可降级为不签名）
    PROFILE_DIR="${HOME}/Library/MobileDevice/Provisioning Profiles"
    if ! grep -rqsa "${APPSTORE_PROFILE}" "${PROFILE_DIR}" 2>/dev/null; then
        echo "Error: Provisioning profile '${APPSTORE_PROFILE}' not found, cannot build App Store ipa."
        exit 1
    fi
    if ! grep -rqsa "${APPSTORE_APPEX_PROFILE}" "${PROFILE_DIR}" 2>/dev/null; then
        echo "Error: Provisioning profile '${APPSTORE_APPEX_PROFILE}' not found, cannot build App Store ipa."
        exit 1
    fi

    patchPbxprojForAppStore

    # SWIFT_ACTIVE_COMPILATION_CONDITIONS=BUILDAPPSTORE：
    # 上架包排除开发者登录（本地 UserSig 登录入口/逻辑/密钥均被条件编译移除）
    ${BUILD_BIN} -workspace ${WORKSPACE_NAME}.xcworkspace -scheme ${SCHEME_NAME} -configuration Release -sdk ${BUILD_SDK_IPHONEOS} -derivedDataPath ${BUILD_DIR} \
        CODE_SIGN_STYLE=Manual \
        CODE_SIGN_IDENTITY="iPhone Distribution" \
        DEVELOPMENT_TEAM="${APPSTORE_TEAM_ID}" \
        SWIFT_ACTIVE_COMPILATION_CONDITIONS="BUILDAPPSTORE"
    BUILD_RESULT=$?

    restorePbxproj

    if [[ ${BUILD_RESULT} -ne 0 ]]; then
        echo "build iphoneos ${APPSTORE_APP_NAME} failed !!! "
        exit 1
    else
        echo "build iphoneos ${APPSTORE_APP_NAME} success !!!"
    fi

    # 产物重命名为上架 App 名（与旧上架产物一致）
    mv ${DEMO_BUILD_DIR}/Release-iphoneos/${APP_NAME}.app ${DEMO_BUILD_DIR}/Release-iphoneos/${APPSTORE_APP_NAME}.app
    mv ${DEMO_BUILD_DIR}/Release-iphoneos/${APP_NAME}.app.dSYM ${DEMO_BUILD_DIR}/Release-iphoneos/${APPSTORE_APP_NAME}.app.dSYM

    # 压缩 Payload 生成 ipa
    echo "zip ${APPSTORE_APP_NAME}.ipa"
    mkdir ${DEMO_BUILD_DIR}/Release-iphoneos/Payload
    cp -R ${DEMO_BUILD_DIR}/Release-iphoneos/${APPSTORE_APP_NAME}.app ${DEMO_BUILD_DIR}/Release-iphoneos/Payload
    cd ${DEMO_BUILD_DIR}/Release-iphoneos

    # App Store 上架包必须包含 SwiftSupport 文件夹，否则 App Store 校验会报 ITMS-90426。
    # xcodebuild build + 手工 zip 不会生成该文件夹，这里从 Xcode 工具链按 app 实际嵌入的 libswift*.dylib 补齐。
    rm -rf SwiftSupport
    mkdir -p SwiftSupport/iphoneos
    APP_FRAMEWORKS_DIR="Payload/${APPSTORE_APP_NAME}.app/Frameworks"
    TOOLCHAIN_LIB_DIR="$(xcode-select -p)/Toolchains/XcodeDefault.xctoolchain/usr/lib"
    if [ -d "${APP_FRAMEWORKS_DIR}" ]; then
        for swiftlib in $(ls "${APP_FRAMEWORKS_DIR}" 2>/dev/null | grep -E '^libswift.*\.dylib$'); do
            srclib=$(find "${TOOLCHAIN_LIB_DIR}" -path "*/iphoneos/${swiftlib}" 2>/dev/null | grep -vi simulator | head -n 1)
            if [ -n "${srclib}" ]; then
                cp "${srclib}" "SwiftSupport/iphoneos/${swiftlib}"
                echo "SwiftSupport: add ${swiftlib} (from ${srclib})"
            else
                echo "Warning: SwiftSupport source not found for ${swiftlib}, ITMS-90426 may recur !!!"
            fi
        done
    fi

    ITUNES_ARTWORK_ARG=""
    if [ -f iTunesArtwork ]; then
        ITUNES_ARTWORK_ARG="iTunesArtwork"
    fi
    # SwiftSupport 仅在非空时打入包内：空目录会被 Apple 判 ITMS-90424；
    # 部署目标 >= iOS 15 后 app 不再嵌入 Swift 运行时库，此时本就不需要 SwiftSupport。
    SWIFTSUPPORT_ARG=""
    if [ -n "$(ls -A SwiftSupport/iphoneos 2>/dev/null)" ]; then
        SWIFTSUPPORT_ARG="SwiftSupport"
    else
        echo "SwiftSupport: no embedded swift dylibs, skip empty folder (avoid ITMS-90424)"
    fi
    zip -r -q ${OUTPUT_DIR}/${APPSTORE_APP_NAME}_${SDK_VERSION}.ipa Payload ${ITUNES_ARTWORK_ARG} ${SWIFTSUPPORT_ARG}
    rm -rf Payload
    rm -rf SwiftSupport

    # 复制当前版本的符号表
    echo "copy ${APPSTORE_APP_NAME} dSYM"
    cp -rf ${DEMO_BUILD_DIR}/Release-iphoneos/${APPSTORE_APP_NAME}.app.dSYM ${SYMBOLS_DIR}/
}

# 压缩符号表
function zipSymbols() {
    echo ">>>>>>>>> zipSymbols begin !!!"
    FINAL_SYMBOLS_DIR=temp_symbols_ios_${1}_${SDK_VERSION}
    cd ${OUTPUT_DIR}
    mv symbols_ios_${SDK_VERSION} ${FINAL_SYMBOLS_DIR}
    zip -r ${FINAL_SYMBOLS_DIR}.zip ${FINAL_SYMBOLS_DIR}
    rm -rf ${FINAL_SYMBOLS_DIR}
    if [[ $? -ne 0 ]]; then
        echo "zip Symbols failed !!! "
        exit 1
    else
        echo "zip Symbols success !!!"
    fi
}

######################## 3、构建主流程 ########################

# 前置检查：TUICallKit_Swift 必须为本仓库源码
trap 'restorePbxproj' EXIT
checkLocalDependencies

rm -rf ${OUTPUT_DIR}
mkdir -p ${OUTPUT_DIR}
mkdir -p ${SYMBOLS_DIR}

if [[ "${BUILD_APP_STORE}" == "true" ]]; then
    # App Store 上架包：上架标准版本号与显示名（与旧上架产物一致）
    echo "-------------------- build ${APPSTORE_APP_NAME} (App Store) start --------------------"
    if [ -f "${CHATDEMO_PLIST_PATH}" ]; then
        /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${APP_BUILD_NO}" "${CHATDEMO_PLIST_PATH}"
        /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${APP_VERSION}" "${CHATDEMO_PLIST_PATH}"
        /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName ${APPSTORE_DISPLAY_NAME}" "${CHATDEMO_PLIST_PATH}"
        # 上架包 title（App Store Connect/上传后台展示名），仅上架包生效，下方构建 ChatDemo 前会恢复
        /usr/libexec/PlistBuddy -c "Set :CFBundleName ${APPSTORE_BUNDLE_NAME}" "${CHATDEMO_PLIST_PATH}"
    fi
    # 扩展版本号与主包对齐，避免 App Store 警告 ITMS-90473（CFBundleVersion/ShortVersionString Mismatch）
    # 注意：扩展 plist 默认不含这两个 key，Set 会静默失败，需回退 Add
    if [ -f "${APPEX_PLIST_PATH}" ]; then
        /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${APP_BUILD_NO}" "${APPEX_PLIST_PATH}" 2>/dev/null || \
        /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string ${APP_BUILD_NO}" "${APPEX_PLIST_PATH}"
        /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${APP_VERSION}" "${APPEX_PLIST_PATH}" 2>/dev/null || \
        /usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string ${APP_VERSION}" "${APPEX_PLIST_PATH}"
    fi
    buildAppStoreIpa
    zipSymbols "AppStore"
    echo "-------------------- build ${APPSTORE_APP_NAME} (App Store) end --------------------"

    echo "-------------------- build ${SCHEME_NAME} start --------------------"
    mkdir -p ${SYMBOLS_DIR}
    if [ -f "${CHATDEMO_PLIST_PATH}" ]; then
        /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${SDK_VERSION}" "${CHATDEMO_PLIST_PATH}"
        /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${SDK_VERSION}" "${CHATDEMO_PLIST_PATH}"
        /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName ChatDemo" "${CHATDEMO_PLIST_PATH}"
        # 恢复 CFBundleName，避免上架分支的改名影响开发包
        /usr/libexec/PlistBuddy -c 'Set :CFBundleName $(PRODUCT_NAME)' "${CHATDEMO_PLIST_PATH}"
    fi
    buildChatDemo
    zipSymbols "${SCHEME_NAME}"
    echo "-------------------- build ${SCHEME_NAME} end --------------------"
else
    # ChatDemo
    echo "-------------------- build ${SCHEME_NAME} start --------------------"
    if [ -f "${CHATDEMO_PLIST_PATH}" ]; then
        /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${SDK_VERSION}" "${CHATDEMO_PLIST_PATH}"
        /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${SDK_VERSION}" "${CHATDEMO_PLIST_PATH}"
    fi
    buildChatDemo
    zipSymbols "${SCHEME_NAME}"
    echo "-------------------- build ${SCHEME_NAME} end --------------------"
fi

echo "-------------------- Build completed --------------------"
echo "Generated files:"
if [[ "${BUILD_APP_STORE}" == "true" ]]; then
    echo "- Application IPA: ${OUTPUT_DIR}/${APPSTORE_APP_NAME}_${SDK_VERSION}.ipa"
    echo "- Application IPA: ${OUTPUT_DIR}/${APP_NAME}_${SDK_VERSION}.ipa"
else
    echo "- Application IPA: ${OUTPUT_DIR}/${APP_NAME}_${SDK_VERSION}.ipa"
fi
