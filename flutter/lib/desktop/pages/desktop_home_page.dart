import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:password_strength/password_strength.dart';
import 'package:flutter_hbb/common/widgets/custom_password.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/desktop/widgets/update_progress.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/state_model.dart';
import 'package:flutter_hbb/realteq/i18n.dart';
import 'package:flutter_hbb/realteq/rt.dart';
import 'package:flutter_hbb/realteq/shell.dart';
import 'package:flutter_hbb/utils/multi_window_manager.dart';
import 'package:flutter_hbb/utils/platform_channel.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:window_size/window_size.dart' as window_size;

class DesktopHomePage extends StatefulWidget {
  const DesktopHomePage({Key? key}) : super(key: key);

  @override
  State<DesktopHomePage> createState() => _DesktopHomePageState();
}

const borderColor = Color(0xFFA8967A);

class _DesktopHomePageState extends State<DesktopHomePage>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver, WindowListener {
  @override
  bool get wantKeepAlive => true;
  var systemError = '';
  StreamSubscription? _uniLinksSubscription;
  var svcStopped = false.obs;
  var watchIsCanScreenRecording = false;
  var watchIsProcessTrust = false;
  var watchIsInputMonitoring = false;
  var watchIsCanRecordAudio = false;
  Timer? _updateTimer;
  bool isCardClosed = false;

  final RxBool _block = false.obs;

  final GlobalKey _childKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return buildRemoteBlock(
        block: _block,
        mask: true,
        use: canBeBlocked,
        child: ChangeNotifierProvider.value(
          value: gFFI.serverModel,
          child: Obx(() => RealteqShell(
                key: _childKey,
                statusStrip: _statusStrip(context, stateGlobal.updateUrl.value),
                onInstall: () async {
                  await rustDeskWinManager.closeAllSubWindows();
                  bind.mainGotoInstall();
                },
              )),
        ));
  }

  Widget? _statusStrip(BuildContext context, String updateUrl) {
    String? msg;
    String? btn;
    VoidCallback? action;
    if (systemError.isNotEmpty) {
      msg = systemError;
    } else if (updateUrl.isNotEmpty &&
        !isCardClosed &&
        isWindows &&
        bind.mainIsInstalled()) {
      msg = rtEn
          ? 'A new version is available (${bind.mainGetNewVersion()}).'
          : 'Há uma nova versão disponível (${bind.mainGetNewVersion()}).';
      btn = tr('Atualizar');
      action = () => handleUpdate(updateUrl);
    } else if (isWindows &&
        !bind.isDisableInstallation() &&
        bind.mainIsInstalled() &&
        bind.mainIsInstalledLowerVersion()) {
      msg = tr('A instalação está numa versão mais antiga.');
      btn = tr('Atualizar instalação');
      action = () async {
        await rustDeskWinManager.closeAllSubWindows();
        bind.mainUpdateMe();
      };
    }
    if (msg == null) return null;
    final p = context.rt;
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: p.accent.withOpacity(0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.accent.withOpacity(0.5)),
      ),
      child: Row(children: [
        Icon(Icons.info_outline_rounded, size: 18, color: p.accent),
        const SizedBox(width: 10),
        Expanded(
            child: Text(msg, style: TextStyle(fontSize: 13, color: p.ink))),
        if (btn != null && action != null)
          RtButton(btn, primary: true, onTap: action),
      ]),
    );
  }

  @override
  void initState() {
    super.initState();
    if (bind.mainGetLocalOption(key: 'realteq-dock-init') != 'Y') {
      mainSetLocalBoolOption(kOptionAllowMultiEdgeToolbarDock, true);
      bind.mainSetLocalOption(key: 'realteq-dock-init', value: 'Y');
    }
    _updateTimer = periodic_immediate(const Duration(seconds: 1), () async {
      try {
        final st = jsonDecode(await bind.mainGetConnectStatus())
            as Map<String, dynamic>;
        final n = st['status_num'] as int;
        stateGlobal.svcStatus.value = n == 0
            ? SvcStatus.connecting
            : (n == 1 ? SvcStatus.ready : SvcStatus.notReady);
        try {
          stateGlobal.videoConnCount.value = st['video_conn_count'] as int;
        } catch (_) {}
      } catch (_) {}
      await gFFI.serverModel.fetchID();
      final error = await bind.mainGetError();
      if (systemError != error) {
        systemError = error;
        setState(() {});
      }
      final v = await mainGetBoolOption(kOptionStopService);
      if (v != svcStopped.value) {
        svcStopped.value = v;
        setState(() {});
      }
      if (watchIsCanScreenRecording) {
        if (bind.mainIsCanScreenRecording(prompt: false)) {
          watchIsCanScreenRecording = false;
          setState(() {});
        }
      }
      if (watchIsProcessTrust) {
        if (bind.mainIsProcessTrusted(prompt: false)) {
          watchIsProcessTrust = false;
          setState(() {});
        }
      }
      if (watchIsInputMonitoring) {
        if (bind.mainIsCanInputMonitoring(prompt: false)) {
          watchIsInputMonitoring = false;
          // Do not notify for now.
          // Monitoring may not take effect until the process is restarted.
          // rustDeskWinManager.call(
          //     WindowType.RemoteDesktop, kWindowDisableGrabKeyboard, '');
          setState(() {});
        }
      }
      if (watchIsCanRecordAudio) {
        if (isMacOS) {
          Future.microtask(() async {
            if ((await osxCanRecordAudio() ==
                PermissionAuthorizeType.authorized)) {
              watchIsCanRecordAudio = false;
              setState(() {});
            }
          });
        } else {
          watchIsCanRecordAudio = false;
          setState(() {});
        }
      }
    });
    Get.put<RxBool>(svcStopped, tag: 'stop-service');
    rustDeskWinManager.registerActiveWindowListener(onActiveWindowChanged);

    screenToMap(window_size.Screen screen) => {
          'frame': {
            'l': screen.frame.left,
            't': screen.frame.top,
            'r': screen.frame.right,
            'b': screen.frame.bottom,
          },
          'visibleFrame': {
            'l': screen.visibleFrame.left,
            't': screen.visibleFrame.top,
            'r': screen.visibleFrame.right,
            'b': screen.visibleFrame.bottom,
          },
          'scaleFactor': screen.scaleFactor,
        };

    bool isChattyMethod(String methodName) {
      switch (methodName) {
        case kWindowBumpMouse: return true;
      }

      return false;
    }

    rustDeskWinManager.setMethodHandler((call, fromWindowId) async {
      if (!isChattyMethod(call.method)) {
        debugPrint(
          "[Main] call ${call.method} with args ${call.arguments} from window $fromWindowId");
      }
      if (call.method == kWindowMainWindowOnTop) {
        windowOnTop(null);
      } else if (call.method == kWindowRefreshCurrentUser) {
        gFFI.userModel.refreshCurrentUser();
      } else if (call.method == kWindowGetScreenList) {
        return jsonEncode(
            (await window_size.getScreenList()).map(screenToMap).toList());
      } else if (call.method == kWindowActionRebuild) {
        reloadCurrentWindow();
      } else if (call.method == kWindowEventShow) {
        await rustDeskWinManager.registerActiveWindow(call.arguments["id"]);
      } else if (call.method == kWindowEventHide) {
        await rustDeskWinManager.unregisterActiveWindow(call.arguments['id']);
      } else if (call.method == kWindowConnect) {
        await connectMainDesktop(
          call.arguments['id'],
          isFileTransfer: call.arguments['isFileTransfer'],
          isViewCamera: call.arguments['isViewCamera'],
          isTerminal: call.arguments['isTerminal'],
          isTcpTunneling: call.arguments['isTcpTunneling'],
          isRDP: call.arguments['isRDP'],
          password: call.arguments['password'],
          forceRelay: call.arguments['forceRelay'],
          connToken: call.arguments['connToken'],
          loginMethod: call.arguments['loginMethod'] ?? '',
        );
      } else if (call.method == kWindowBumpMouse) {
        return RdPlatformChannel.instance.bumpMouse(
          dx: call.arguments['dx'],
          dy: call.arguments['dy']);
      } else if (call.method == kWindowEventMoveTabToNewWindow) {
        final args = call.arguments.split(',');
        int? windowId;
        try {
          windowId = int.parse(args[0]);
        } catch (e) {
          debugPrint("Failed to parse window id '${call.arguments}': $e");
        }
        WindowType? windowType;
        try {
          windowType = WindowType.values.byName(args[3]);
        } catch (e) {
          debugPrint("Failed to parse window type '${call.arguments}': $e");
        }
        if (windowId != null && windowType != null) {
          await rustDeskWinManager.moveTabToNewWindow(
              windowId, args[1], args[2], windowType);
        }
      } else if (call.method == kWindowEventOpenMonitorSession) {
        final args = jsonDecode(call.arguments);
        final windowId = args['window_id'] as int;
        final peerId = args['peer_id'] as String;
        final display = args['display'] as int;
        final displayCount = args['display_count'] as int;
        final windowType = args['window_type'] as int;
        final screenRect = parseParamScreenRect(args);
        await rustDeskWinManager.openMonitorSession(
            windowId, peerId, display, displayCount, screenRect, windowType);
      } else if (call.method == kWindowEventRemoteWindowCoords) {
        final windowId = int.tryParse(call.arguments);
        if (windowId != null) {
          return jsonEncode(
              await rustDeskWinManager.getOtherRemoteWindowCoords(windowId));
        }
      }
    });
    _uniLinksSubscription = listenUniLinks();

    if (bind.isIncomingOnly()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateWindowSize();
      });
    }
    WidgetsBinding.instance.addObserver(this);
    windowManager.addListener(this);
    if (bind.mainGetLocalOption(key: 'realteq-theme-init') != 'Y') {
      MyTheme.changeDarkMode(ThemeMode.dark);
      bind.mainSetLocalOption(key: 'realteq-theme-init', value: 'Y');
    }
  }

  bool _minimized = false;

  @override
  void onWindowEvent(String eventName) {
    super.onWindowEvent(eventName);
    if (eventName == 'minimize') {
      _minimized = true;
    } else if (eventName == 'maximize' || eventName == 'restore') {
      if (_minimized && isWindows) {
        Get.forceAppUpdate();
      }
      _minimized = false;
    }
  }

  @override
  void onWindowEnterFullScreen() {
    stateGlobal.resizeEdgeSize.value = 0;
  }

  @override
  void onWindowLeaveFullScreen() {
    stateGlobal.resizeEdgeSize.value = stateGlobal.isMaximized.isTrue
        ? kMaximizeEdgeSize
        : windowResizeEdgeSize;
  }

  @override
  void onWindowClose() {
    super.onWindowClose();
    bind.mainOnMainWindowClose();
  }

  _updateWindowSize() {
    RenderObject? renderObject = _childKey.currentContext?.findRenderObject();
    if (renderObject == null) {
      return;
    }
    if (renderObject is RenderBox) {
      final size = renderObject.size;
      if (size != imcomingOnlyHomeSize) {
        imcomingOnlyHomeSize = size;
        windowManager.setSize(getIncomingOnlyHomeSize());
      }
    }
  }

  @override
  void dispose() {
    _uniLinksSubscription?.cancel();
    Get.delete<RxBool>(tag: 'stop-service');
    _updateTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      shouldBeBlocked(_block, canBeBlocked);
    }
  }
}

void setPasswordDialog({VoidCallback? notEmptyCallback}) async {
  final p0 = TextEditingController(text: "");
  final p1 = TextEditingController(text: "");
  var errMsg0 = "";
  var errMsg1 = "";
  final localPasswordSet =
      (await bind.mainGetCommon(key: "local-permanent-password-set")) == "true";
  final permanentPasswordSet =
      (await bind.mainGetCommon(key: "permanent-password-set")) == "true";
  final presetPassword = permanentPasswordSet && !localPasswordSet;
  var canSubmit = false;
  final RxString rxPass = "".obs;
  final rules = [
    DigitValidationRule(),
    UppercaseValidationRule(),
    LowercaseValidationRule(),
    // SpecialCharacterValidationRule(),
    MinCharactersValidationRule(8),
  ];
  final maxLength = bind.mainMaxEncryptLen();
  final statusTip = localPasswordSet
      ? translate('password-hidden-tip')
      : (presetPassword ? translate('preset-password-in-use-tip') : '');
  final showStatusTipOnMobile =
      statusTip.isNotEmpty && !isDesktop && !isWebDesktop;

  gFFI.dialogManager.show((setState, close, context) {
    updateCanSubmit() {
      canSubmit = p0.text.trim().isNotEmpty || p1.text.trim().isNotEmpty;
    }

    submit() async {
      if (!canSubmit) {
        return;
      }
      setState(() {
        errMsg0 = "";
        errMsg1 = "";
      });
      final pass = p0.text.trim();
      if (pass.isNotEmpty) {
        final Iterable violations = rules.where((r) => !r.validate(pass));
        if (violations.isNotEmpty) {
          setState(() {
            errMsg0 =
                '${translate('Prompt')}: ${violations.map((r) => r.name).join(', ')}';
          });
          return;
        }
      }
      if (p1.text.trim() != pass) {
        setState(() {
          errMsg1 =
              '${translate('Prompt')}: ${translate("The confirmation is not identical.")}';
        });
        return;
      }
      final ok = await bind.mainSetPermanentPasswordWithResult(password: pass);
      if (!ok) {
        setState(() {
          errMsg0 = '${translate('Prompt')}: ${translate("Failed")}';
        });
        return;
      }
      if (pass.isNotEmpty) {
        notEmptyCallback?.call();
      }
      close();
    }

    final p = context.rt;
    InputDecoration deco(String err) => InputDecoration(
          errorText: err.isNotEmpty ? err : null,
          counterText: '',
          filled: true,
          fillColor: p.field,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: p.line)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: p.line)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: p.accent, width: 1.5)),
        );
    return CustomAlertDialog(
      contentBoxConstraints: const BoxConstraints(maxWidth: 460),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.key_rounded, color: p.accent, size: 22),
            const SizedBox(width: 10),
            Text(tr('Definir senha mestra'),
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600, color: p.ink)),
          ]),
          const SizedBox(height: 18),
          const RtLabel('Nova senha'),
          const SizedBox(height: 6),
          TextField(
            obscureText: true,
            controller: p0,
            autofocus: true,
            maxLength: maxLength,
            style: TextStyle(color: p.ink),
            decoration: deco(errMsg0),
            onChanged: (value) {
              rxPass.value = value.trim();
              setState(() {
                errMsg0 = '';
                updateCanSubmit();
              });
            },
          ).workaroundFreezeLinuxMint(),
          const SizedBox(height: 10),
          Obx(() {
            final strength = estimatePasswordStrength(rxPass.value);
            final empty = rxPass.value.isEmpty;
            Color seg(double min) => empty || strength < min
                ? p.line
                : (strength < 0.33
                    ? p.danger
                    : (strength < 0.67 ? p.accent : p.ok));
            return Row(children: [
              for (final m in const [0.0, 0.33, 0.67]) ...[
                Expanded(
                    child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                            color: seg(m),
                            borderRadius: BorderRadius.circular(3)))),
                const SizedBox(width: 6),
              ],
              SizedBox(
                width: 64,
                child: Text(
                    empty
                        ? ''
                        : translate(strength < 0.33
                            ? 'Weak'
                            : (strength < 0.67 ? 'Medium' : 'Strong')),
                    textAlign: TextAlign.end,
                    style: TextStyle(fontSize: 12, color: p.mut)),
              ),
            ]);
          }),
          const SizedBox(height: 16),
          const RtLabel('Confirmação'),
          const SizedBox(height: 6),
          TextField(
            obscureText: true,
            controller: p1,
            maxLength: maxLength,
            style: TextStyle(color: p.ink),
            decoration: deco(errMsg1),
            onChanged: (value) {
              setState(() {
                errMsg1 = '';
                updateCanSubmit();
              });
            },
          ).workaroundFreezeLinuxMint(),
          if (statusTip.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(children: [
              Icon(Icons.info_outline_rounded, color: p.accent, size: 16),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(statusTip,
                      style: TextStyle(fontSize: 12.5, color: p.mut))),
            ]),
          ],
          const SizedBox(height: 14),
          Obx(() => Wrap(
                runSpacing: 8,
                spacing: 8,
                children: rules.map((e) {
                  final ok = e.validate(rxPass.value.trim());
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: ok ? p.ok.withOpacity(0.16) : p.panel2,
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(ok ? Icons.check_rounded : Icons.circle_outlined,
                          size: 13, color: ok ? p.ok : p.mut),
                      const SizedBox(width: 5),
                      Text(e.name,
                          style: TextStyle(
                              fontSize: 12, color: ok ? p.ok : p.mut)),
                    ]),
                  );
                }).toList(),
              )),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            RtButton('Cancelar', onTap: close),
            if (localPasswordSet) ...[
              const SizedBox(width: 10),
              RtButton('Remover', danger: true, onTap: () async {
                setState(() {
                  errMsg0 = "";
                  errMsg1 = "";
                });
                final ok =
                    await bind.mainSetPermanentPasswordWithResult(password: "");
                if (!ok) {
                  setState(() {
                    errMsg0 = '${translate('Prompt')}: ${translate("Failed")}';
                  });
                  return;
                }
                close();
              }),
            ],
            const SizedBox(width: 10),
            RtButton('OK', primary: true, onTap: canSubmit ? submit : null),
          ]),
        ],
      ),
      onSubmit: canSubmit ? submit : null,
      onCancel: close,
    );
  });
}
