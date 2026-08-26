#!/usr/bin/env bash

export LANG="zh_CN.UTF-8"
export LC_ALL="zh_CN.UTF-8"

# 蓝盾默认变量
MajorVersion=${MajorVersion-0}
MinorVersion=${MinorVersion-0}
FixVersion=${FixVersion-0}
BuildNo=${BuildNo-0}

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
CHATDEMO_PLIST_PATH=${SHELL_DIR}/ChatDemo/Info.plist

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

# 前置检查：AtomicXCore / TUICallKit_Swift / RTCRoomEngine 全部走本地源码依赖（:path），
# 与本地开发环境一致；CI 需先把 tuikit_engine 源码检出/上传到工作区根目录的 tuikit_engine/。
function checkLocalDependencies() {
    local missing=0

    if [[ -f "/Volumes/data/workspace/tuikit_engine/RTCRoomEngine.podspec" ]] \
        || [[ -f "${SHELL_DIR}/../../../../../tuikit_engine/RTCRoomEngine.podspec" ]]; then
        echo "Found RTCRoomEngine source dependency (tuikit_engine)"
    else
        echo "Error: tuikit_engine/RTCRoomEngine.podspec not found."
        missing=1
    fi

    if [[ -f "${SHELL_DIR}/../../../../../tuikit_engine/atomicx/swift/AtomicXCore/AtomicXCore.podspec" ]]; then
        echo "Found AtomicXCore source dependency (tuikit_engine)"
    else
        echo "Error: tuikit_engine/atomicx/swift/AtomicXCore/AtomicXCore.podspec not found."
        missing=1
    fi

    if [[ -f "${SHELL_DIR}/../../call/TUICallKit_Swift.podspec" ]]; then
        echo "Found TUICallKit_Swift source dependency (in-repo)"
    else
        echo "Error: ios/chat/call/TUICallKit_Swift.podspec not found."
        missing=1
    fi

    if [[ ${missing} -ne 0 ]]; then
        echo "Error: 本地源码依赖缺失。请先将 tuikit_engine 源码检出/上传到 CI 工作区，"
        echo "Error: 使其与本仓库保持与本地一致的相对布局（工作区根目录下 client_uikit/ 与 tuikit_engine/ 平级）。"
        exit 1
    fi
}

# 修改 RTCRoomEngine.podspec 路径为云端环境
function modifyRTCRoomEnginePaths() {
    # 尝试多个可能的 podspec 路径
    local possible_paths=(
        "/Volumes/data/workspace/tuikit_engine/RTCRoomEngine.podspec"
        "${SHELL_DIR}/../../../../../tuikit_engine/RTCRoomEngine.podspec"
    )

    local podspec_path=""
    for path in "${possible_paths[@]}"; do
        if [[ -f "${path}" ]]; then
            podspec_path="${path}"
            break
        fi
    done

    if [[ -z "${podspec_path}" ]]; then
        echo "Error: RTCRoomEngine.podspec not found in any expected location."
        echo "Error: 请先将 tuikit_engine 源码检出/上传到 CI 工作区根目录。"
        exit 1
    fi

    echo "Found RTCRoomEngine.podspec at: ${podspec_path}"
    echo "Modifying RTCRoomEngine.podspec for build compatibility..."

    # 备份原始文件
    cp "${podspec_path}" "${podspec_path}.backup"

    # 1. 修改路径 - 将相对路径改为云端绝对路径
    local cloud_path="/Volumes/data/workspace/tuikit_engine/"
    sed -i "" "s|\${PROJECT_DIR}/../../../|${cloud_path}|g" "${podspec_path}"

    # 2. 添加模块名配置
    if ! grep -q "module_name.*RTCRoomEngine" "${podspec_path}"; then
        awk '/spec.name.*RTCRoomEngine/ { print; print "  spec.module_name = '\''RTCRoomEngine'\''"; next } { print }' "${podspec_path}" > "${podspec_path}.tmp" && mv "${podspec_path}.tmp" "${podspec_path}"
    fi

    # 3. 添加 call_record 和 call_record/oc 到 extensions 数组
    if ! grep -q "src/extensions/call_record" "${podspec_path}"; then
        echo "Adding call_record implementation to extensions..."
        awk '
        /^  extensions = \[/ { in_extensions = 1; print; next }
        in_extensions && /^  \]/ {
            print "    '\''src/extensions/call_record/*'\'',"
            print "    '\''src/extensions/call_record/oc/*'\'',"
            print ""
            in_extensions = 0
        }
        { print }
        ' "${podspec_path}" > "${podspec_path}.tmp" && mv "${podspec_path}.tmp" "${podspec_path}"
    fi

    # 4. 添加 call pipeline 到 pipeline 数组
    if ! grep -q "src/pipeline/call" "${podspec_path}"; then
        echo "Adding call pipeline to pipeline array..."
        awk '
        /^  pipeline = \[/ { in_pipeline = 1; print; next }
        in_pipeline && /^  \]/ {
            print "    '\''src/pipeline/call/**/*'\'',"
            in_pipeline = 0
        }
        { print }
        ' "${podspec_path}" > "${podspec_path}.tmp" && mv "${podspec_path}.tmp" "${podspec_path}"
    fi

    # 5. 添加 call_record 头文件路径到 project_header_files
    if ! grep -q "src/extensions/call_record.*\.h" "${podspec_path}"; then
        echo "Adding call_record headers to project_header_files..."
        awk '
        /src\/platform_adapter\/oc\/\*\*\/\*\.h/ {
            print
            print "            '\''src/extensions/call_record/*.h'\'',"
            print "            '\''src/extensions/call_record/oc/*.h'\'',"
            next
        }
        { print }
        ' "${podspec_path}" > "${podspec_path}.tmp" && mv "${podspec_path}.tmp" "${podspec_path}"
    fi

    # 6. 注释掉 platform_adapter/oc/call 的排除规则
    echo "Uncommenting platform_adapter/oc/call exclusion..."
    sed -i "" "s/^[[:space:]]*'src\/platform_adapter\/oc\/call\/\*\.{h,mm,cc}',/            # 'src\/platform_adapter\/oc\/call\/*.{h,mm,cc}', # 注释掉以解决 TUICallEngine 链接问题/" "${podspec_path}"

    # 7. Add CoreTelephony framework dependency
    if ! grep -q "CoreTelephony" "${podspec_path}"; then
        echo "Adding CoreTelephony framework..."
        if grep -q "spec.frameworks" "${podspec_path}"; then
            sed -i "" "s/spec.frameworks.*=.*'/spec.frameworks = 'CoreTelephony', '/g" "${podspec_path}"
        else
            awk '/spec.requires_arc/ { print; print "  spec.frameworks = '\''CoreTelephony'\''"; next } { print }' "${podspec_path}" > "${podspec_path}.tmp" && mv "${podspec_path}.tmp" "${podspec_path}"
        fi
    fi

    echo "RTCRoomEngine.podspec modifications completed"

    export MODIFIED_PODSPEC_PATH="${podspec_path}"

    # 验证 podspec 语法
    echo "Validating RTCRoomEngine.podspec syntax..."
    if ! pod spec lint "${podspec_path}" --allow-warnings --quick > /dev/null 2>&1; then
        echo "Warning: RTCRoomEngine.podspec validation failed, but continuing..."
    else
        echo "RTCRoomEngine.podspec validation passed"
    fi
}

# 恢复 RTCRoomEngine.podspec 原始路径
function restoreRTCRoomEnginePaths() {
    if [[ -n "${MODIFIED_PODSPEC_PATH}" && -f "${MODIFIED_PODSPEC_PATH}.backup" ]]; then
        echo "Restoring original RTCRoomEngine.podspec..."
        mv "${MODIFIED_PODSPEC_PATH}.backup" "${MODIFIED_PODSPEC_PATH}"
        echo "RTCRoomEngine.podspec restored from: ${MODIFIED_PODSPEC_PATH}"
        unset MODIFIED_PODSPEC_PATH
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

# 任何退出路径（成功/失败/Ctrl-C）都恢复 RTCRoomEngine.podspec，避免污染工作区。
trap 'restoreRTCRoomEnginePaths' EXIT

# 前置检查：三个依赖全部走本地源码（:path），缺失则直接失败并给出指引
checkLocalDependencies

# 修改 RTCRoomEngine.podspec 路径为云端环境
modifyRTCRoomEnginePaths

rm -rf ${OUTPUT_DIR}
mkdir -p ${OUTPUT_DIR}
mkdir -p ${SYMBOLS_DIR}

# ChatDemo
echo "-------------------- build ${SCHEME_NAME} start --------------------"
if [ -f "${CHATDEMO_PLIST_PATH}" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${SDK_VERSION}" "${CHATDEMO_PLIST_PATH}"
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${SDK_VERSION}" "${CHATDEMO_PLIST_PATH}"
fi
buildChatDemo
zipSymbols "${SCHEME_NAME}"
echo "-------------------- build ${SCHEME_NAME} end --------------------"

# 清理和恢复
restoreRTCRoomEnginePaths

echo "-------------------- Build completed --------------------"
echo "Generated files:"
echo "- Application IPA: ${OUTPUT_DIR}/${APP_NAME}_${SDK_VERSION}.ipa"
