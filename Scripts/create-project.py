from pathlib import Path
import json
root=Path(__file__).resolve().parents[1]
assets=root/'Plata/Assets.xcassets'
def write_json(p,o):
 p.parent.mkdir(parents=True,exist_ok=True); p.write_text(json.dumps(o,indent=2)+'\n')
info={'author':'xcode','version':1}
# Original 3x Figma exports; preserve their scale and native tab template rendering.
account_images=["account-card-physical","account-card-digital","account-card-add","account-transactions-sphere","account-deposit","account-bill-pay","account-transfer","account-withdraw","account-copy","account-share","account-chevron","account-balance-chevron","account-tab-home","account-tab-pay","account-tab-invest","account-tab-invite","account-tab-support"]
for name in account_images + ["order-avatar", "order-add-person"]:
 write_json(assets/f'{name}.imageset/Contents.json',{'images':[{'filename':name+'.png','idiom':'universal','scale':'3x'}],'info':info,'properties':{'template-rendering-intent':'template' if name.startswith('account-tab') else 'original'}})
account_colors={'AccountTextPrimary':('121416',1),'AccountTextSecondary':('171C26',.6),'AccountCardText':('272C34',1),'AccountNeutral':('002570',.04),'AccountDetails':('2401FE',1),'AccountWithdraw':('FCE2E5',1),'AccountPaymentAccent':('FF5D15',1)}
for name,(rgb,alpha) in account_colors.items():
 components=dict(zip(['red','green','blue'],[f'{int(rgb[i:i+2],16)/255:.9f}' for i in (0,2,4)]),alpha=f'{alpha:.9f}')
 write_json(assets/f'{name}.colorset/Contents.json',{'colors':[{'idiom':'universal','color':{'color-space':'srgb','components':components}}],'info':info})
write_json(assets/'Contents.json',{'info':info})
for name in ['hola-platacard','hola-platacard-back','pinklovers-card','colors-of-life-card','settings']:
 write_json(assets/f'{name}.imageset/Contents.json',{'images':[{'filename':name+'.png','idiom':'universal'}],'info':info})
for name in ['gallery-digital','gallery-plastic','gallery-metal','gallery-plata-plus']:
 ext='svg' if name=='gallery-plata-plus' else 'png'
 write_json(assets/f'{name}.imageset/Contents.json',{'images':[{'filename':name+'.'+ext,'idiom':'universal'}],'info':info,'properties':{'preserves-vector-representation':ext=='svg','template-rendering-intent':'original'}})
for name,rgb in {'ModalBackground':'F5F6F9','CardTitle':'333333','SetupBadge':'ABABAB','AccentColor':'FF5000'}.items():
 write_json(assets/f'{name}.colorset/Contents.json',{'colors':[{'idiom':'universal','color':{'color-space':'srgb','components':dict(zip(['red','green','blue'],[str(int(rgb[i:i+2],16)/255) for i in (0,2,4)]),alpha='1.000')}}],'info':info})
# Deterministic dependency-free project; all source files are explicitly listed.
objects=[]
def uid(n): return f'{n:024X}'
def obj(n,s): objects.append(f'{uid(n)} = {{ {s} }};')
sources=['PlataApp.swift','AccountView.swift','AccountDates.swift','CardOrderSheet.swift','CardDesign.swift','CardOrderingView.swift','CardSetupFlow.swift','CardPhysics.swift','MetalCard.swift','TextMorph.swift','MorphingTitle.swift','MorphSettingsView.swift','PlataMetalV1/PlataMetalCardView.swift','PlataMetalV1/PlataMetalCardGeometry.swift','PlataMetalV1/PlataMetalCardDemoView.swift','PlataDigitalV1/PlataDigitalArtwork.swift','PlataDigitalV1/PlataDigitalCardMaterial.swift','PlataDigitalV1/PlataDigitalCardView.swift','PlataDigitalV1/PlataDigitalCardDemoView.swift','PlataPlasticV1/PlataPlasticArtwork.swift','PlataPlasticV1/PlataPlasticGeometry.swift','PlataPlasticV1/PlataPlasticCardMaterial.swift','PlataPlasticV1/PlataPlasticCardView.swift','PlataPlasticV1/PlataPlasticCardDemoView.swift']
# Keep source IDs separate from fixed asset/product/test IDs as the flow grows.
for i,name in enumerate(sources):
 obj(300+i,f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {name}; sourceTree = "<group>";')
 obj(400+i,f'isa = PBXBuildFile; fileRef = {uid(300+i)};')
obj(110,'isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>";')
obj(210,f'isa = PBXBuildFile; fileRef = {uid(110)};')
# Raw namespaced PNG/HDR folder: Copy Bundle Resources preserves original bytes.
obj(850,'isa = PBXFileReference; lastKnownFileType = folder; path = PlataMetalV1/Resources/plata_metal_v1; sourceTree = "<group>";')
obj(851,f'isa = PBXBuildFile; fileRef = {uid(850)};')
obj(860,'isa = PBXFileReference; lastKnownFileType = folder; path = PlataPlasticV1/Resources/plata_plastic_v1; sourceTree = "<group>";')
obj(861,f'isa = PBXBuildFile; fileRef = {uid(860)};')
obj(870,'isa = PBXFileReference; lastKnownFileType = folder; path = PlataDigitalV1/Resources/plata_digital_v1; sourceTree = "<group>";')
obj(871,f'isa = PBXBuildFile; fileRef = {uid(870)};')
obj(111,'isa = PBXFileReference; explicitFileType = wrapper.application; path = Plata.app; sourceTree = BUILT_PRODUCTS_DIR;')
uitests=['CardFlowUITests.swift','AccountScreenUITests.swift','PlataMetalV1UITests.swift','PlataDigitalV1UITests.swift','PlataPlasticV1UITests.swift']
for i,name in enumerate(uitests):
 obj(112+2*i,f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {name}; sourceTree = "<group>";')
 obj(212+2*i,f'isa = PBXBuildFile; fileRef = {uid(112+2*i)};')
obj(113,'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = PlataUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
obj(1,f'isa = PBXGroup; children = ({uid(2)}, {uid(4)}, {uid(3)}); sourceTree = "<group>";')
obj(2,'isa = PBXGroup; path = Plata; sourceTree = "<group>"; children = ('+', '.join(uid(300+i) for i in range(len(sources)))+', '+uid(110)+', '+uid(850)+', '+uid(860)+', '+uid(870)+');')
obj(3,f'isa = PBXGroup; name = Products; children = ({uid(111)}, {uid(113)}); sourceTree = "<group>";')
obj(4,'isa = PBXGroup; path = PlataUITests; children = ('+', '.join(uid(112+2*i) for i in range(len(uitests)))+'); sourceTree = "<group>";')
for n,isa,files in [(10,'PBXSourcesBuildPhase',[400+i for i in range(len(sources))]),(11,'PBXResourcesBuildPhase',[210,851,861,871]),(12,'PBXFrameworksBuildPhase',[]),(13,'PBXSourcesBuildPhase',[212+2*i for i in range(len(uitests))]),(14,'PBXResourcesBuildPhase',[]),(15,'PBXFrameworksBuildPhase',[])]:
 obj(n,f'isa = {isa}; buildActionMask = 2147483647; files = ('+', '.join(uid(f) for f in files)+'); runOnlyForDeploymentPostprocessing = 0;')
obj(240,'isa = PBXShellScriptBuildPhase; alwaysOutOfDate = 1; buildActionMask = 2147483647; files = (); inputPaths = (); outputPaths = (); inputFileListPaths = ("$(SRCROOT)/Scripts/pbr-inputs.xcfilelist"); outputFileListPaths = ("$(SRCROOT)/Scripts/pbr-outputs.xcfilelist"); name = "Install brushed-metal PBR maps"; runOnlyForDeploymentPostprocessing = 0; shellPath = /bin/bash; shellScript = "\\\"${SRCROOT}/Scripts/install-pbr-materials.sh\\\"\\n";')
obj(20,f'isa = PBXNativeTarget; buildConfigurationList = {uid(31)}; buildPhases = ({uid(10)}, {uid(12)}, {uid(11)}, {uid(240)}); buildRules = (); dependencies = (); name = Plata; productName = Plata; productReference = {uid(111)}; productType = "com.apple.product-type.application";')
obj(21,f'isa = PBXNativeTarget; buildConfigurationList = {uid(32)}; buildPhases = ({uid(13)}, {uid(15)}, {uid(14)}); buildRules = (); dependencies = ({uid(23)}); name = PlataUITests; productName = PlataUITests; productReference = {uid(113)}; productType = "com.apple.product-type.bundle.ui-testing";')
obj(22,f'isa = PBXContainerItemProxy; containerPortal = {uid(50)}; proxyType = 1; remoteGlobalIDString = {uid(20)}; remoteInfo = Plata;')
obj(23,f'isa = PBXTargetDependency; target = {uid(20)}; targetProxy = {uid(22)};')
for n,configs in [(30,[40,41]),(31,[42,43]),(32,[44,45])]: obj(n,f'isa = XCConfigurationList; buildConfigurations = ({uid(configs[0])}, {uid(configs[1])}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
common='CLANG_ENABLE_MODULES = YES; SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 18.0; SWIFT_VERSION = 5.0; ENABLE_USER_SCRIPT_SANDBOXING = YES;'
app='PRODUCT_NAME = "$(TARGET_NAME)"; PRODUCT_BUNDLE_IDENTIFIER = com.sytykhandrei.platacards; GENERATE_INFOPLIST_FILE = YES; INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES; INFOPLIST_KEY_UILaunchScreen_Generation = YES; INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = UIInterfaceOrientationPortrait; INFOPLIST_KEY_CFBundleDisplayName = Plata; TARGETED_DEVICE_FAMILY = 1; CODE_SIGN_STYLE = Automatic; DEVELOPMENT_TEAM = U696752Z36; CURRENT_PROJECT_VERSION = 1; MARKETING_VERSION = 1.0; ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor; ENABLE_PREVIEWS = YES;'
test='PRODUCT_NAME = "$(TARGET_NAME)"; PRODUCT_BUNDLE_IDENTIFIER = com.sytykhandrei.platacards.uitests; GENERATE_INFOPLIST_FILE = YES; TARGETED_DEVICE_FAMILY = 1; TEST_TARGET_NAME = Plata; CODE_SIGN_STYLE = Automatic;'
for n,name,settings in [(40,'Debug',common+' DEBUG_INFORMATION_FORMAT = dwarf; ENABLE_TESTABILITY = YES; SWIFT_OPTIMIZATION_LEVEL = "-Onone"; SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;'),(41,'Release',common+' SWIFT_COMPILATION_MODE = wholemodule; SWIFT_OPTIMIZATION_LEVEL = "-O";'),(42,'Debug',app),(43,'Release',app),(44,'Debug',test),(45,'Release',test)]: obj(n,f'isa = XCBuildConfiguration; name = {name}; buildSettings = {{ {settings} }};')
obj(50,f'isa = PBXProject; attributes = {{ BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 2600; }}; buildConfigurationList = {uid(30)}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; knownRegions = (en, Base); mainGroup = {uid(1)}; productRefGroup = {uid(3)}; projectDirPath = ""; projectRoot = ""; targets = ({uid(20)}, {uid(21)});')
project=root/'Plata.xcodeproj'; project.mkdir(exist_ok=True)
(project/'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(objects)+f'\n}}; rootObject = {uid(50)}; }}\n')
scheme=project/'xcshareddata/xcschemes/Plata.xcscheme'; scheme.parent.mkdir(parents=True,exist_ok=True)
def ref(n,name):return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid(n)}" BuildableName="{name}" BlueprintName="{name.split(".")[0]}" ReferencedContainer="container:Plata.xcodeproj"/>'
scheme.write_text('<?xml version="1.0" encoding="UTF-8"?><Scheme LastUpgradeVersion="2600" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">'+ref(20,'Plata.app')+'</BuildActionEntry></BuildActionEntries></BuildAction><TestAction buildConfiguration="Debug" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">'+ref(21,'PlataUITests.xctest')+'</TestableReference></Testables></TestAction><LaunchAction buildConfiguration="Debug" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">'+ref(20,'Plata.app')+'</BuildableProductRunnable></LaunchAction><ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">'+ref(20,'Plata.app')+'</BuildableProductRunnable></ProfileAction><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>')
