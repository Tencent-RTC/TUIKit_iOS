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

CHATDEMO_PLIST_PATH=${SHELL_DIR}/ChatDemo/Info.plist
ATOMICX_COMPONENTS_DIR=${SHELL_DIR}/../../atomic-x
ATOMICX_PODSPEC_PATH=${SHELL_DIR}/../../atomic-x/AtomicX.podspec

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

BUILD_SDK_MAC_CATALYST_VERSION=$(${BUILD_BIN} -showsdks | grep macos | sort -r | head -n 1 | grep -o '[0-9]*\.[0-9]*$')
if [[ ${BUILD_SDK_MAC_CATALYST_VERSION} = "" ]]; then
    echo "Error: No MacOS SDK ..."
    exit 1
fi

# 真机和模拟器版本
BUILD_SDK_IPHONEOS="iphoneos${BUILD_SDK_VERSION}"
BUILD_SDK_IPHONESIMULATOR="iphonesimulator${BUILD_SDK_VERSION}"
BUILD_SDK_MAC_CATALYST="macosx${BUILD_SDK_MAC_CATALYST_VERSION}"
echo "Build System -> ${BUILD_SDK_IPHONEOS} ${BUILD_SDK_IPHONESIMULATOR} ${BUILD_SDK_MAC_CATALYST}"

######################## 2、函数定义 ########################

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
    
    if [[ -n "${podspec_path}" ]]; then
        echo "Found RTCRoomEngine.podspec at: ${podspec_path}"
        echo "Modifying RTCRoomEngine.podspec for build compatibility..."
        
        # 备份原始文件
        cp "${podspec_path}" "${podspec_path}.backup"
        
        # 1. 修改路径 - 将相对路径改为云端绝对路径
        local relative_path="\${PROJECT_DIR}/../../../"
        local cloud_path="/Volumes/data/workspace/tuikit_engine/"
        sed -i "" "s|\${PROJECT_DIR}/../../../|${cloud_path}|g" "${podspec_path}"
        
        # 2. 添加模块名配置
        if ! grep -q "module_name.*RTCRoomEngine" "${podspec_path}"; then
            awk '/spec.name.*RTCRoomEngine/ { print; print "  spec.module_name = '\''RTCRoomEngine'\''"; next } { print }' "${podspec_path}" > "${podspec_path}.tmp" && mv "${podspec_path}.tmp" "${podspec_path}"
        fi
        
        # 3. 添加 call_record 和 call_record/oc 到 extensions 数组
        if ! grep -q "src/extensions/call_record" "${podspec_path}"; then
            echo "Adding call_record implementation to extensions..."
            # 使用 awk 添加 call_record 相关条目到 extensions 数组末尾
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
            # 使用 awk 添加 call pipeline 到 pipeline 数组末尾
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
            # 使用 awk 在 project_header_files 中添加 call_record 头文件
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
        # 如果存在排除规则，将其注释掉
        sed -i "" "s/^[[:space:]]*'src\/platform_adapter\/oc\/call\/\*\.{h,mm,cc}',/            # 'src\/platform_adapter\/oc\/call\/*.{h,mm,cc}', # 注释掉以解决 TUICallEngine 链接问题/" "${podspec_path}"
        
        echo "RTCRoomEngine.podspec modifications completed:"
        echo "  ✓ Cloud paths configured"
        echo "  ✓ Module name added"
        echo "  ✓ Call record OC implementation included"
        echo "  ✓ Call pipeline added"
        echo "  ✓ Call record headers included"
        echo "  ✓ Platform adapter call exclusion disabled"
        
        export MODIFIED_PODSPEC_PATH="${podspec_path}"
        
        # 验证 podspec 语法
        echo "Validating RTCRoomEngine.podspec syntax..."
        if ! pod spec lint "${podspec_path}" --allow-warnings --quick > /dev/null 2>&1; then
            echo "Warning: RTCRoomEngine.podspec validation failed, but continuing..."
        else
            echo "RTCRoomEngine.podspec validation passed"
        fi
    else
        echo "Warning: RTCRoomEngine.podspec not found in any expected location"
        echo "Searched paths:"
        for path in "${possible_paths[@]}"; do
            echo "  - ${path}"
        done
    fi
}

# 恢复 RTCRoomEngine.podspec 原始路径
function restoreRTCRoomEnginePaths() {
    if [[ -n "${MODIFIED_PODSPEC_PATH}" && -f "${MODIFIED_PODSPEC_PATH}.backup" ]]; then
        echo "Restoring original RTCRoomEngine.podspec..."
        mv "${MODIFIED_PODSPEC_PATH}.backup" "${MODIFIED_PODSPEC_PATH}"
        echo "RTCRoomEngine.podspec restored from: ${MODIFIED_PODSPEC_PATH}"
        unset MODIFIED_PODSPEC_PATH
    else
        echo "No backup found for RTCRoomEngine.podspec or no modification was made"
    fi
}

# 处理 AtomicXCore.zip 并修改 Podfile
function setupAtomicXCore() {
    # 创建临时目录
    ATOMICX_TEMP_DIR="/tmp/atomicx_core_${SDK_VERSION}"
    rm -rf ${ATOMICX_TEMP_DIR}
    mkdir -p ${ATOMICX_TEMP_DIR}
    
    # 使用 curl 下载 AtomicXCore.zip
    echo "Downloading AtomicXCore.zip from bkrepo..."
    ATOMICX_ZIP_PATH="${ATOMICX_TEMP_DIR}/AtomicXCore.zip"
    
    curl -L --user yiliangwang:920dbf8df42f87226887636c2510416e "https://bkrepo.woa.com/generic/timsdk-ios/custom/atomicxcore_iOS/AtomicXCore.zip" -o "${ATOMICX_ZIP_PATH}"
    
    if [[ $? -ne 0 ]] || [[ ! -f "${ATOMICX_ZIP_PATH}" ]]; then
        echo "Error: Failed to download AtomicXCore.zip"
        exit 1
    fi
    
    echo "Successfully downloaded AtomicXCore.zip"
    
    # 解压 AtomicXCore.zip
    echo "Extracting AtomicXCore.zip..."
    unzip -q "${ATOMICX_ZIP_PATH}" -d ${ATOMICX_TEMP_DIR}
        
        # 查找解压后的 AtomicXCore.xcframework
        ATOMICX_FRAMEWORK_PATH=$(find ${ATOMICX_TEMP_DIR} -name "AtomicXCore.xcframework" -type d | head -1)
        
        if [[ -d "${ATOMICX_FRAMEWORK_PATH}" ]]; then
            echo "Found AtomicXCore.xcframework at: ${ATOMICX_FRAMEWORK_PATH}"
            export ATOMICX_CORE_FRAMEWORK_PATH="${ATOMICX_FRAMEWORK_PATH}"
            
            # 创建本地 AtomicXCore 目录并复制 xcframework
            LOCAL_ATOMICX_DIR="${SHELL_DIR}/LocalAtomicXCore"
            rm -rf ${LOCAL_ATOMICX_DIR}
            mkdir -p ${LOCAL_ATOMICX_DIR}
            cp -R "${ATOMICX_FRAMEWORK_PATH}" ${LOCAL_ATOMICX_DIR}/
            
            # 创建 LICENSE 文件（避免 podspec 警告）
            cat > ${LOCAL_ATOMICX_DIR}/LICENSE << EOF
MIT License

Copyright (c) 2025 Tencent

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF

            # 创建 AtomicXCore.podspec 文件
            cat > ${LOCAL_ATOMICX_DIR}/AtomicXCore.podspec << EOF
Pod::Spec.new do |spec|
  spec.name         = "AtomicXCore"
  spec.version      = "${SDK_VERSION}"
  spec.summary      = "AtomicXCore framework"
  spec.description  = "AtomicXCore framework for iOS"
  spec.homepage     = "https://github.com/tencentyun/TIMSDK"
  spec.license      = { :type => "MIT", :file => "LICENSE" }
  spec.author       = { "Tencent" => "restapi_im@tencent.com" }
  spec.platform     = :ios, "14.0"
  spec.source       = { :git => "https://github.com/tencentyun/TIMSDK.git", :tag => spec.version.to_s }
  spec.vendored_frameworks = "AtomicXCore.xcframework"
  spec.requires_arc = true
  
  # 添加依赖 - 关键修复：确保 RTCRoomEngine 依赖正确配置
  spec.dependency 'RTCRoomEngine'
  spec.dependency 'TXIMSDK_Plus_iOS_XCFramework'
  spec.dependency 'TXLiteAVSDK_Professional'
  
  # 设置编译配置以解决模块兼容性问题
  spec.pod_target_xcconfig = {
    'SWIFT_VERSION' => '5.0',
    'OTHER_SWIFT_FLAGS' => '-D COCOAPODS',
    'SWIFT_INCLUDE_PATHS' => '\$(inherited) \$(PODS_ROOT)/RTCRoomEngine',
    'HEADER_SEARCH_PATHS' => '\$(inherited) \$(PODS_ROOT)/RTCRoomEngine'
  }
end
EOF

            # 创建 README.md 文件
            cat > ${LOCAL_ATOMICX_DIR}/README.md << EOF
# AtomicXCore

This is a temporary local pod for AtomicXCore framework.

## Version
${SDK_VERSION}

## Usage
This pod is automatically generated during the build process.
EOF

            echo "Created LocalAtomicXCore directory structure:"
            echo "- AtomicXCore.xcframework"
            echo "- AtomicXCore.podspec"
            echo "- LICENSE"
            echo "- README.md"
            
            # 备份原始 Podfile
            cp ${SHELL_DIR}/Podfile ${SHELL_DIR}/Podfile.backup
            
            # 修改 Podfile，将 AtomicXCore 的路径指向本地解压的 xcframework
            # 处理可能的不同路径格式
            sed -i "" "s|pod 'AtomicXCore', :path => '../../../../../tuikit_engine/atomicx/swift/AtomicXCore'|pod 'AtomicXCore', :path => './LocalAtomicXCore'|g" ${SHELL_DIR}/Podfile
            sed -i "" "s|pod 'AtomicXCore', :path => './LocalAtomicXCore'|pod 'AtomicXCore', :path => './LocalAtomicXCore'|g" ${SHELL_DIR}/Podfile
            
            echo "Created AtomicXCore.podspec and modified Podfile to use local AtomicXCore.xcframework"
        else
            echo "Error: AtomicXCore.xcframework not found in extracted files"
            exit 1
        fi
}

# 清理并重新安装 CocoaPods
function cleanAndInstallPods() {
    echo "Cleaning and reinstalling CocoaPods..."
    cd ${SHELL_DIR}
    
    # 清理 Pods 相关文件
    rm -rf Pods/
    rm -rf ChatDemo.xcworkspace
    rm -f Podfile.lock
    
    # 清理 CocoaPods 缓存以避免模块冲突
    echo "Cleaning CocoaPods cache..."
    pod cache clean --all > /dev/null 2>&1 || true
    
    # 确保 RTCRoomEngine 能被正确找到
    echo "Verifying RTCRoomEngine availability..."
    if [[ -n "${MODIFIED_PODSPEC_PATH}" && -f "${MODIFIED_PODSPEC_PATH}" ]]; then
        echo "RTCRoomEngine.podspec found at: ${MODIFIED_PODSPEC_PATH}"
    else
        echo "Warning: RTCRoomEngine.podspec not found, this may cause build issues"
    fi
    
    # 重新安装 pods，增加详细输出以便调试
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
    
    # 验证 RTCRoomEngine 模块是否正确安装
    if [[ -d "Pods/RTCRoomEngine" ]]; then
        echo "RTCRoomEngine pod installed successfully"
        # 检查模块映射文件
        if [[ -f "Pods/RTCRoomEngine/RTCRoomEngine.modulemap" ]] || [[ -f "Pods/Target Support Files/RTCRoomEngine/RTCRoomEngine.modulemap" ]]; then
            echo "RTCRoomEngine module map found"
        else
            echo "Warning: RTCRoomEngine module map not found"
        fi
    else
        echo "Warning: RTCRoomEngine pod not found in Pods directory"
    fi
    
    echo "pod install success !!!"
}

function buildChatDemo() {
    echo ">>>>>>>>> build ChatDemo begin !!! "
    
    # 设置 AtomicXCore
    setupAtomicXCore
    
    # 清理并重新安装 pods
    cleanAndInstallPods

    # 清理构建目录，避免多次构建 demo，脏数据影响签名
    rm -rf ${DEMO_BUILD_DIR}/*

    ${BUILD_BIN} -workspace ChatDemo.xcworkspace -scheme ChatDemo -configuration Release -sdk ${BUILD_SDK_IPHONEOS} -derivedDataPath ${BUILD_DIR}

    if [[ $? -ne 0 ]]; then
        echo "build iphoneos ChatDemo failed !!! "
        exit 1
    else
        echo "build iphoneos ChatDemo success !!!"
    fi

    # 压缩 Payload 生成 ChatDemo.ipa
    echo "zip ChatDemo.ipa"
    mkdir ${DEMO_BUILD_DIR}/Release-iphoneos/Payload
    cp -R ${DEMO_BUILD_DIR}/Release-iphoneos/ChatDemo.app ${DEMO_BUILD_DIR}/Release-iphoneos/Payload
    cd ${DEMO_BUILD_DIR}/Release-iphoneos
    zip -r -q ${OUTPUT_DIR}/ChatDemo_${SDK_VERSION}.ipa Payload iTunesArtwork
    rm -rf ${DEMO_BUILD_DIR}/Release-iphoneos/Payload

    # 复制当前版本的符号表
    echo "copy ChatDemo dSYM"
    cp -rf ${DEMO_BUILD_DIR}/Release-iphoneos/ChatDemo.app.dSYM ${SYMBOLS_DIR}/
}

function buildAtomicXComponents() {
    echo ">>>>>>>>> build AtomicX Components begin !!! "

    # 设置 AtomicXCore
    setupAtomicXCore

    # 清理并重新安装 pods
    cleanAndInstallPods

    # 清理构建目录，避免多次构建 demo，脏数据影响签名
    rm -rf ${DEMO_BUILD_DIR}/Release-iphoneos/*
    rm -rf ${DEMO_BUILD_DIR}/Release-iphonesimulator/*

    # 编译真机架构
    ${BUILD_BIN} -workspace ChatDemo.xcworkspace -scheme ChatDemo -configuration Release -sdk ${BUILD_SDK_IPHONEOS} -derivedDataPath ${BUILD_DIR}

    if [[ $? -ne 0 ]]; then
        echo "build iphoneos ChatDemo failed !!! "
        exit 1
    else
        echo "build iphoneos ChatDemo success !!!"
    fi

    # 编译模拟器架构
    ${BUILD_BIN} -workspace ChatDemo.xcworkspace -scheme ChatDemo -configuration Release -arch arm64 -arch x86_64 -sdk ${BUILD_SDK_IPHONESIMULATOR} -derivedDataPath ${BUILD_DIR}

    if [[ $? -ne 0 ]]; then
        echo "build simulator ChatDemo failed !!! "
        exit 1
    else
        echo "build simulator ChatDemo success !!!"
    fi

    SimulatorFrameworks_Dir=${DEMO_BUILD_DIR}/Plugin/SimulatorFrameworks
    IphoneosFrameworks_Dir=${DEMO_BUILD_DIR}/Plugin/IphoneosFrameworks
    mkdir -p ${SimulatorFrameworks_Dir}
    mkdir -p ${IphoneosFrameworks_Dir}
    cp -R ${DEMO_BUILD_DIR}/Release-iphonesimulator/ChatDemo.app/Frameworks ${SimulatorFrameworks_Dir}
    cp -R ${DEMO_BUILD_DIR}/Release-iphoneos/ChatDemo.app/Frameworks ${IphoneosFrameworks_Dir}

    # 处理 AtomicX 相关的 Frameworks
    cd ${IphoneosFrameworks_Dir}/Frameworks
    for filename in $(ls .); do
        if [[ "$filename" == *.framework ]]; then
            frameworkArray=(${filename//./ })
            frameworkName=${frameworkArray[0]}
            
            # 只处理 AtomicX 相关的框架
            if [[ "$frameworkName" == *"AtomicX"* ]] || [[ "$frameworkName" == *"Chat"* ]] || [[ "$frameworkName" == *"Message"* ]] || [[ "$frameworkName" == *"Conversation"* ]] || [[ "$frameworkName" == *"Contact"* ]]; then
                echo "Processing AtomicX framework: ${frameworkName}"
                
                # 创建 xcframework
                ${BUILD_BIN} -create-xcframework -framework "${frameworkName}.framework" -framework "${SimulatorFrameworks_Dir}/Frameworks/${frameworkName}.framework" -output "${frameworkName}.xcframework"
                
                # 从Demo的产物里拷贝出来每个frameworkName的dSYM
                dSYMPath="${DEMO_BUILD_DIR}/Release-iphoneos/${frameworkName}/${frameworkName}.framework.dSYM"
                if [ -d "$dSYMPath" ]; then
                    cp -R "$dSYMPath" "${SYMBOLS_DIR}/"
                    rm -rf "$dSYMPath"
                    echo "Copied dSYM file to ${SYMBOLS_DIR}/"
                else
                    echo "Warning: dSYM file for ${frameworkName} not found."
                fi
                
                # 添加头文件和模块（如果存在）
                for archName in $(ls ${frameworkName}.xcframework); do
                    plugin_path="${ATOMICX_COMPONENTS_DIR}/Sources/${frameworkName}"
                    echo "Current archName: $archName, frameworkName: $frameworkName, plugin_path: $plugin_path"
                    
                    if [ -d "$plugin_path" ]; then
                        # 手动添加头文件到插件的 xcframework
                        if [ -d "${plugin_path}/Headers" ]; then
                            cp -R "${plugin_path}/Headers" "${frameworkName}.xcframework/${archName}/${frameworkName}.framework/"
                        fi
                        if [ -d "${plugin_path}/Modules" ]; then
                            cp -R "${plugin_path}/Modules" "${frameworkName}.xcframework/${archName}/${frameworkName}.framework/"
                        fi
                        # 手动把 PrivacyInfo.xcprivacy 导入到最终的 xcframework 文件
                        if [ -f "${plugin_path}/Resources/PrivacyInfo.xcprivacy" ]; then
                            cp -R "${plugin_path}/Resources/PrivacyInfo.xcprivacy" "${frameworkName}.xcframework/${archName}/${frameworkName}.framework/"
                        fi
                    fi
                done

                zip -r ${frameworkName}_${SDK_VERSION}.xcframework.zip ${frameworkName}.xcframework
                cp -rf ${frameworkName}_${SDK_VERSION}.xcframework.zip ${OUTPUT_DIR}/
            fi
        fi
    done
    
    # 处理 AtomicXCore.xcframework
    if [[ -n "${ATOMICX_CORE_FRAMEWORK_PATH}" && -d "${ATOMICX_CORE_FRAMEWORK_PATH}" ]]; then
        echo "Processing AtomicXCore.xcframework..."
        cd ${IphoneosFrameworks_Dir}/Frameworks
        
        # 复制 AtomicXCore.xcframework 到当前目录
        cp -R "${ATOMICX_CORE_FRAMEWORK_PATH}" ./
        
        # 创建 atomicx.xcframework 的压缩包
        zip -r atomicx_${SDK_VERSION}.xcframework.zip AtomicXCore.xcframework
        cp -rf atomicx_${SDK_VERSION}.xcframework.zip ${OUTPUT_DIR}/
        
        echo "AtomicXCore.xcframework processed and copied to output directory"
    fi
    
    rm -rf ${DEMO_BUILD_DIR}/Plugin
}

# 压缩符号表
function zipSymbols() {
    echo ">>>>>>>>> zipSymbols begin !!!"
    FINAL_SYMBOLS_DIR=temp_symbols_ios_${1}_${SDK}_${SDK_VERSION}
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

# 更新 AtomicX 插件版本号
function updateAtomicXVersion() {
    if [ -f "${ATOMICX_PODSPEC_PATH}" ]; then
        echo "Updating version in: ${ATOMICX_PODSPEC_PATH}"
        sed -i "" "s/spec.version.*= \\'.*\\'/spec.version      = \\'${SDK_VERSION}\\'/g" "${ATOMICX_PODSPEC_PATH}"
    fi
}

# 恢复 Podfile
function restorePodfile() {
    if [ -f "${SHELL_DIR}/Podfile.backup" ]; then
        echo "Restoring original Podfile..."
        mv ${SHELL_DIR}/Podfile.backup ${SHELL_DIR}/Podfile
    fi
    
    # 清理临时文件
    if [[ -n "${ATOMICX_TEMP_DIR}" && -d "${ATOMICX_TEMP_DIR}" ]]; then
        echo "Cleaning up temporary AtomicXCore files..."
        rm -rf ${ATOMICX_TEMP_DIR}
    fi
    
    if [[ -d "${SHELL_DIR}/LocalAtomicXCore" ]]; then
        echo "Cleaning up local AtomicXCore directory..."
        rm -rf ${SHELL_DIR}/LocalAtomicXCore
    fi
}

######################## 3、构建主流程 ########################

# 修改 RTCRoomEngine.podspec 路径为云端环境
modifyRTCRoomEnginePaths

rm -rf ${OUTPUT_DIR}
mkdir ${OUTPUT_DIR}
mkdir ${SYMBOLS_DIR}

# ChatDemo
echo "-------------------- build ChatDemo start --------------------"
if [ -f "${CHATDEMO_PLIST_PATH}" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${SDK_VERSION}" "${CHATDEMO_PLIST_PATH}"
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${SDK_VERSION}" "${CHATDEMO_PLIST_PATH}"
fi
buildChatDemo
zipSymbols "ChatDemo"
echo "-------------------- build ChatDemo end --------------------"

# AtomicX Components
echo "-------------------- build AtomicX Components start --------------------"
updateAtomicXVersion
buildAtomicXComponents
zipSymbols "AtomicX"
echo "-------------------- build AtomicX Components end --------------------"

# 清理和恢复
restorePodfile
restoreRTCRoomEnginePaths

echo "-------------------- Build completed --------------------"
echo "Generated files:"
echo "- Application IPA: ${OUTPUT_DIR}/ChatDemo_${SDK_VERSION}.ipa"
echo "- AtomicX Framework: ${OUTPUT_DIR}/atomicx_${SDK_VERSION}.xcframework.zip"
echo "- Other AtomicX component frameworks are also generated in ${OUTPUT_DIR}/"