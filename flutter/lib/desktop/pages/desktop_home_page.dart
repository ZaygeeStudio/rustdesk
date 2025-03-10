import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart' hide MenuItem;
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/desktop/pages/connection_page.dart';
import 'package:flutter_hbb/desktop/pages/desktop_setting_page.dart';
import 'package:flutter_hbb/desktop/widgets/popup_menu.dart';
import 'package:flutter_hbb/desktop/widgets/material_mod_popup_menu.dart'
    as mod_menu;
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/server_model.dart';
import 'package:flutter_hbb/utils/multi_window_manager.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:window_manager/window_manager.dart';

class _MenubarTheme {
  static const Color commonColor = MyTheme.accent;
  // kMinInteractiveDimension
  static const double height = 25.0;
  static const double dividerHeight = 12.0;
}

class DesktopHomePage extends StatefulWidget {
  const DesktopHomePage({Key? key}) : super(key: key);

  @override
  State<DesktopHomePage> createState() => _DesktopHomePageState();
}

const borderColor = Color(0xFF2F65BA);

class _DesktopHomePageState extends State<DesktopHomePage>
    with TrayListener, WindowListener, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void onWindowClose() async {
    super.onWindowClose();
    // close all sub windows
    if (await windowManager.isPreventClose()) {
      try {
        await Future.wait([
          saveWindowPosition(WindowType.Main),
          rustDeskWinManager.closeAllSubWindows()
        ]);
      } catch (err) {
        debugPrint("$err");
      } finally {
        await windowManager.setPreventClose(false);
        await windowManager.close();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Row(
      children: [
        buildServerInfo(context),
        const VerticalDivider(
          width: 1,
          thickness: 1,
        ),
        Expanded(
          child: buildServerBoard(context),
        ),
      ],
    );
  }

  buildServerInfo(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: gFFI.serverModel,
      child: Container(
        width: 200,
        color: MyTheme.color(context).bg,
        child: Column(
          children: [
            buildTip(context),
            buildIDBoard(context),
            buildPasswordBoard(context),
          ],
        ),
      ),
    );
  }

  buildServerBoard(BuildContext context) {
    return Container(
      color: MyTheme.color(context).grayBg,
      child: ConnectionPage(),
    );
  }

  buildIDBoard(BuildContext context) {
    final model = gFFI.serverModel;
    return Container(
      margin: const EdgeInsets.only(left: 20, right: 11),
      height: 57,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Container(
            width: 2,
            decoration: const BoxDecoration(color: MyTheme.accent),
          ).marginOnly(top: 5),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 25,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          translate("ID"),
                          style: TextStyle(
                              fontSize: 14,
                              color: MyTheme.color(context).lightText),
                        ).marginOnly(top: 5),
                        buildPopupMenu(context)
                      ],
                    ),
                  ),
                  Flexible(
                    child: GestureDetector(
                      onDoubleTap: () {
                        Clipboard.setData(
                            ClipboardData(text: model.serverId.text));
                        showToast(translate("Copied"));
                      },
                      child: TextFormField(
                        controller: model.serverId,
                        readOnly: true,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.only(bottom: 20),
                        ),
                        style: TextStyle(
                          fontSize: 22,
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildPopupMenu(BuildContext context) {
    var position;
    RxBool hover = false.obs;
    return InkWell(
      onTapDown: (detail) {
        final x = detail.globalPosition.dx;
        final y = detail.globalPosition.dy;
        position = RelativeRect.fromLTRB(x, y, x, y);
      },
      onTap: () async {
        final userName = await gFFI.userModel.getUserName();
        final enabledInput = await bind.mainGetOption(key: 'enable-audio');
        final defaultInput = await gFFI.getDefaultAudioInput();
        var menu = <PopupMenuEntry>[
          await genEnablePopupMenuItem(
            translate("Enable Keyboard/Mouse"),
            'enable-keyboard',
          ),
          await genEnablePopupMenuItem(
            translate("Enable Clipboard"),
            'enable-clipboard',
          ),
          await genEnablePopupMenuItem(
            translate("Enable File Transfer"),
            'enable-file-transfer',
          ),
          await genEnablePopupMenuItem(
            translate("Enable TCP Tunneling"),
            'enable-tunnel',
          ),
          genAudioInputPopupMenuItem(enabledInput != "N", defaultInput),
          PopupMenuDivider(),
          PopupMenuItem(
            child: Text(translate("ID/Relay Server")),
            value: 'custom-server',
          ),
          PopupMenuItem(
            child: Text(translate("IP Whitelisting")),
            value: 'whitelist',
          ),
          PopupMenuItem(
            child: Text(translate("Socks5 Proxy")),
            value: 'socks5-proxy',
          ),
          PopupMenuDivider(),
          await genEnablePopupMenuItem(
            translate("Enable Service"),
            'stop-service',
          ),
          // TODO: direct server
          await genEnablePopupMenuItem(
            translate("Always connected via relay"),
            'allow-always-relay',
          ),
          await genEnablePopupMenuItem(
            translate("Start ID/relay service"),
            'stop-rendezvous-service',
          ),
          PopupMenuDivider(),
          userName.isEmpty
              ? PopupMenuItem(
                  child: Text(translate("Login")),
                  value: 'login',
                )
              : PopupMenuItem(
                  child: Text("${translate("Logout")} $userName"),
                  value: 'logout',
                ),
          PopupMenuItem(
            child: Text(translate("Change ID")),
            value: 'change-id',
          ),
          PopupMenuDivider(),
          await genEnablePopupMenuItem(
            translate("Dark Theme"),
            'allow-darktheme',
          ),
          PopupMenuItem(
            child: Text(translate("About")),
            value: 'about',
          ),
        ];
        final v =
            await showMenu(context: context, position: position, items: menu);
        if (v != null) {
          onSelectMenu(v);
        }
      },
      child: Obx(
        () => CircleAvatar(
          radius: 15,
          backgroundColor: hover.value
              ? MyTheme.color(context).grayBg!
              : MyTheme.color(context).bg!,
          child: Icon(
            Icons.more_vert_outlined,
            size: 20,
            color: hover.value
                ? MyTheme.color(context).text
                : MyTheme.color(context).lightText,
          ),
        ),
      ),
      onHover: (value) => hover.value = value,
    );
  }

  buildPasswordBoard(BuildContext context) {
    final model = gFFI.serverModel;
    RxBool refreshHover = false.obs;
    return Container(
      margin: EdgeInsets.only(left: 20.0, right: 16, top: 13, bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Container(
            width: 2,
            height: 52,
            decoration: BoxDecoration(color: MyTheme.accent),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    translate("Password"),
                    style: TextStyle(
                        fontSize: 14, color: MyTheme.color(context).lightText),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onDoubleTap: () {
                            if (model.verificationMethod !=
                                kUsePermanentPassword) {
                              Clipboard.setData(
                                  ClipboardData(text: model.serverPasswd.text));
                              showToast(translate("Copied"));
                            }
                          },
                          child: TextFormField(
                            controller: model.serverPasswd,
                            readOnly: true,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.only(bottom: 2),
                            ),
                            style: TextStyle(fontSize: 15),
                          ),
                        ),
                      ),
                      InkWell(
                        child: Obx(
                          () => Icon(
                            Icons.refresh,
                            color: refreshHover.value
                                ? MyTheme.color(context).text
                                : Color(0xFFDDDDDD),
                            size: 22,
                          ).marginOnly(right: 8, bottom: 2),
                        ),
                        onTap: () => bind.mainUpdateTemporaryPassword(),
                        onHover: (value) => refreshHover.value = value,
                      ),
                      const _PasswordPopupMenu(),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  buildTip(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.only(left: 20.0, right: 16, top: 16.0, bottom: 5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            translate("Your Desktop"),
            style: TextStyle(fontWeight: FontWeight.normal, fontSize: 19),
          ),
          SizedBox(
            height: 10.0,
          ),
          Text(
            translate("desk_tip"),
            overflow: TextOverflow.clip,
            style: TextStyle(
                fontSize: 12,
                color: MyTheme.color(context).lighterText,
                height: 1.25),
          )
        ],
      ),
    );
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    print('click ${menuItem.key}');
    switch (menuItem.key) {
      case "quit":
        exit(0);
      case "show":
        // windowManager.show();
        break;
      default:
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    trayManager.addListener(this);
    windowManager.addListener(this);
    rustDeskWinManager.setMethodHandler((call, fromWindowId) async {
      print(
          "call ${call.method} with args ${call.arguments} from window ${fromWindowId}");
      if (call.method == "main_window_on_top") {
        window_on_top(null);
      }
    });
  }

  @override
  void dispose() {
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    super.dispose();
  }

  void changeTheme(String choice) async {
    if (choice == "Y") {
      Get.changeTheme(MyTheme.darkTheme);
    } else {
      Get.changeTheme(MyTheme.lightTheme);
    }
    Get.find<SharedPreferences>().setString("darkTheme", choice);
    Get.forceAppUpdate();
  }

  void onSelectMenu(String key) async {
    if (key.startsWith('enable-')) {
      final option = await bind.mainGetOption(key: key);
      bind.mainSetOption(key: key, value: option == "N" ? "" : "N");
    } else if (key.startsWith('allow-')) {
      final option = await bind.mainGetOption(key: key);
      final choice = option == "Y" ? "" : "Y";
      bind.mainSetOption(key: key, value: choice);
      if (key == "allow-darktheme") changeTheme(choice);
    } else if (key == "stop-service") {
      final option = await bind.mainGetOption(key: key);
      bind.mainSetOption(key: key, value: option == "Y" ? "" : "Y");
    } else if (key == "change-id") {
      changeIdDialog();
    } else if (key == "custom-server") {
      changeServer();
    } else if (key == "whitelist") {
      changeWhiteList();
    } else if (key == "socks5-proxy") {
      changeSocks5Proxy();
    } else if (key == "about") {
      about();
    } else if (key == "logout") {
      logOut();
    } else if (key == "login") {
      login();
    }
  }

  Future<PopupMenuItem<String>> genEnablePopupMenuItem(
      String label, String key) async {
    final v = await bind.mainGetOption(key: key);
    bool enable;
    if (key == "stop-service") {
      enable = v != "Y";
    } else if (key.startsWith("allow-")) {
      enable = v == "Y";
    } else {
      enable = v != "N";
    }

    return PopupMenuItem(
      child: Row(
        children: [
          Icon(Icons.check,
              color: enable ? null : MyTheme.accent.withAlpha(00)),
          Text(
            label,
            style: genTextStyle(enable),
          ),
        ],
      ),
      value: key,
    );
  }

  TextStyle genTextStyle(bool isPositive) {
    return isPositive
        ? TextStyle()
        : TextStyle(
            color: Colors.redAccent, decoration: TextDecoration.lineThrough);
  }

  PopupMenuItem<String> genAudioInputPopupMenuItem(
      bool enableInput, String defaultAudioInput) {
    final defaultInput = defaultAudioInput.obs;
    final enabled = enableInput.obs;

    return PopupMenuItem(
      child: FutureBuilder<List<String>>(
        future: gFFI.getAudioInputs(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final inputs = snapshot.data!.toList();
            if (Platform.isWindows) {
              inputs.insert(0, translate("System Sound"));
            }
            var inputList = inputs
                .map((e) => PopupMenuItem(
                      child: Row(
                        children: [
                          Obx(() => Offstage(
                              offstage: defaultInput.value != e,
                              child: Icon(Icons.check))),
                          Expanded(
                              child: Tooltip(
                                  message: e,
                                  child: Text(
                                    "$e",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ))),
                        ],
                      ),
                      value: e,
                    ))
                .toList();
            inputList.insert(
                0,
                PopupMenuItem(
                  child: Row(
                    children: [
                      Obx(() => Offstage(
                          offstage: enabled.value, child: Icon(Icons.check))),
                      Expanded(child: Text(translate("Mute"))),
                    ],
                  ),
                  value: "Mute",
                ));
            return PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              child: Container(
                  alignment: Alignment.centerLeft,
                  child: Text(translate("Audio Input"))),
              itemBuilder: (context) => inputList,
              onSelected: (dev) async {
                if (dev == "Mute") {
                  await bind.mainSetOption(
                      key: 'enable-audio', value: enabled.value ? '' : 'N');
                  enabled.value =
                      await bind.mainGetOption(key: 'enable-audio') != 'N';
                } else if (dev != await gFFI.getDefaultAudioInput()) {
                  gFFI.setDefaultAudioInput(dev);
                  defaultInput.value = dev;
                }
              },
            );
          } else {
            return Text("...");
          }
        },
      ),
      value: 'audio-input',
    );
  }

  void about() async {
    final appName = await bind.mainGetAppName();
    final license = await bind.mainGetLicense();
    final version = await bind.mainGetVersion();
    const linkStyle = TextStyle(decoration: TextDecoration.underline);
    gFFI.dialogManager.show((setState, close) {
      return CustomAlertDialog(
        title: Text("About $appName"),
        content: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 500),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                height: 8.0,
              ),
              Text("Version: $version").marginSymmetric(vertical: 4.0),
              InkWell(
                  onTap: () {
                    launchUrlString("https://rustdesk.com/privacy");
                  },
                  child: const Text(
                    "Privacy Statement",
                    style: linkStyle,
                  ).marginSymmetric(vertical: 4.0)),
              InkWell(
                  onTap: () {
                    launchUrlString("https://rustdesk.com");
                  },
                  child: const Text(
                    "Website",
                    style: linkStyle,
                  ).marginSymmetric(vertical: 4.0)),
              Container(
                decoration: const BoxDecoration(color: Color(0xFF2c8cff)),
                padding:
                    const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Copyright &copy; 2022 Purslane Ltd.\n$license",
                            style: const TextStyle(color: Colors.white),
                          ),
                          const Text(
                            "Made with heart in this chaotic world!",
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Colors.white),
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ).marginSymmetric(vertical: 4.0)
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: close, child: Text(translate("OK"))),
        ],
        onSubmit: close,
        onCancel: close,
      );
    });
  }

  void login() {
    loginDialog().then((success) {
      if (success) {
        // refresh frame
        setState(() {});
      }
    });
  }

  void logOut() {
    gFFI.userModel.logOut().then((_) => {setState(() {})});
  }
}

/// common login dialog for desktop
/// call this directly
Future<bool> loginDialog() async {
  String userName = "";
  var userNameMsg = "";
  String pass = "";
  var passMsg = "";
  var userContontroller = TextEditingController(text: userName);
  var pwdController = TextEditingController(text: pass);

  var isInProgress = false;
  var completer = Completer<bool>();
  gFFI.dialogManager.show((setState, close) {
    submit() async {
      setState(() {
        userNameMsg = "";
        passMsg = "";
        isInProgress = true;
      });
      cancel() {
        setState(() {
          isInProgress = false;
        });
      }

      userName = userContontroller.text;
      pass = pwdController.text;
      if (userName.isEmpty) {
        userNameMsg = translate("Username missed");
        cancel();
        return;
      }
      if (pass.isEmpty) {
        passMsg = translate("Password missed");
        cancel();
        return;
      }
      try {
        final resp = await gFFI.userModel.login(userName, pass);
        if (resp.containsKey('error')) {
          passMsg = resp['error'];
          cancel();
          return;
        }
        // {access_token: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJndWlkIjoiMDFkZjQ2ZjgtZjg3OS00MDE0LTk5Y2QtMGMwYzM2MmViZGJlIiwiZXhwIjoxNjYxNDg2NzYwfQ.GZpe1oI8TfM5yTYNrpcwbI599P4Z_-b2GmnwNl2Lr-w,
        // token_type: Bearer, user: {id: , name: admin, email: null, note: null, status: null, grp: null, is_admin: true}}
        debugPrint("$resp");
        completer.complete(true);
      } catch (err) {
        // ignore: avoid_print
        print(err.toString());
        cancel();
        return;
      }
      close();
    }

    cancel() {
      completer.complete(false);
      close();
    }

    return CustomAlertDialog(
      title: Text(translate("Login")),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 500),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(
              height: 8.0,
            ),
            Row(
              children: [
                ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 100),
                    child: Text(
                      "${translate('Username')}:",
                      textAlign: TextAlign.start,
                    ).marginOnly(bottom: 16.0)),
                const SizedBox(
                  width: 24.0,
                ),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        errorText: userNameMsg.isNotEmpty ? userNameMsg : null),
                    controller: userContontroller,
                    focusNode: FocusNode()..requestFocus(),
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 8.0,
            ),
            Row(
              children: [
                ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 100),
                    child: Text("${translate('Password')}:")
                        .marginOnly(bottom: 16.0)),
                const SizedBox(
                  width: 24.0,
                ),
                Expanded(
                  child: TextField(
                    obscureText: true,
                    decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        errorText: passMsg.isNotEmpty ? passMsg : null),
                    controller: pwdController,
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 4.0,
            ),
            Offstage(
                offstage: !isInProgress, child: const LinearProgressIndicator())
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: cancel, child: Text(translate("Cancel"))),
        TextButton(onPressed: submit, child: Text(translate("OK"))),
      ],
      onSubmit: submit,
      onCancel: cancel,
    );
  });
  return completer.future;
}

void setPasswordDialog() async {
  final pw = await bind.mainGetPermanentPassword();
  final p0 = TextEditingController(text: pw);
  final p1 = TextEditingController(text: pw);
  var errMsg0 = "";
  var errMsg1 = "";

  gFFI.dialogManager.show((setState, close) {
    submit() {
      setState(() {
        errMsg0 = "";
        errMsg1 = "";
      });
      final pass = p0.text.trim();
      if (pass.length < 6) {
        setState(() {
          errMsg0 = translate("Too short, at least 6 characters.");
        });
        return;
      }
      if (p1.text.trim() != pass) {
        setState(() {
          errMsg1 = translate("The confirmation is not identical.");
        });
        return;
      }
      bind.mainSetPermanentPassword(password: pass);
      close();
    }

    return CustomAlertDialog(
      title: Text(translate("Set Password")),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 500),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(
              height: 8.0,
            ),
            Row(
              children: [
                ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 100),
                    child: Text(
                      "${translate('Password')}:",
                      textAlign: TextAlign.start,
                    ).marginOnly(bottom: 16.0)),
                const SizedBox(
                  width: 24.0,
                ),
                Expanded(
                  child: TextField(
                    obscureText: true,
                    decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        errorText: errMsg0.isNotEmpty ? errMsg0 : null),
                    controller: p0,
                    focusNode: FocusNode()..requestFocus(),
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 8.0,
            ),
            Row(
              children: [
                ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 100),
                    child: Text("${translate('Confirmation')}:")
                        .marginOnly(bottom: 16.0)),
                const SizedBox(
                  width: 24.0,
                ),
                Expanded(
                  child: TextField(
                    obscureText: true,
                    decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        errorText: errMsg1.isNotEmpty ? errMsg1 : null),
                    controller: p1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: close, child: Text(translate("Cancel"))),
        TextButton(onPressed: submit, child: Text(translate("OK"))),
      ],
      onSubmit: submit,
      onCancel: close,
    );
  });
}

class _PasswordPopupMenu extends StatefulWidget {
  const _PasswordPopupMenu({Key? key}) : super(key: key);

  @override
  State<_PasswordPopupMenu> createState() => _PasswordPopupMenuState();
}

class _PasswordPopupMenuState extends State<_PasswordPopupMenu> {
  final RxBool _tempEnabled = true.obs;
  final RxBool _permEnabled = true.obs;

  List<MenuEntryBase<String>> _buildMenus() {
    return <MenuEntryBase<String>>[
      MenuEntryRadios<String>(
          text: translate('Password type'),
          optionsGetter: () => [
                MenuEntryRadioOption(
                    text: translate('Use temporary password'),
                    value: kUseTemporaryPassword),
                MenuEntryRadioOption(
                    text: translate('Use permanent password'),
                    value: kUsePermanentPassword),
                MenuEntryRadioOption(
                    text: translate('Use both passwords'),
                    value: kUseBothPasswords),
              ],
          curOptionGetter: () async {
            return gFFI.serverModel.verificationMethod;
          },
          optionSetter: (String oldValue, String newValue) async {
            await bind.mainSetOption(
                key: "verification-method", value: newValue);
            await gFFI.serverModel.updatePasswordModel();
            setState(() {
              _tempEnabled.value =
                  gFFI.serverModel.verificationMethod != kUsePermanentPassword;
              _permEnabled.value =
                  gFFI.serverModel.verificationMethod != kUseTemporaryPassword;
            });
          }),
      MenuEntryDivider(),
      MenuEntryButton<String>(
        enabled: _permEnabled,
        childBuilder: (TextStyle? style) => Text(
          translate('Set permanent password'),
          style: style,
        ),
        proc: () {
          setPasswordDialog();
        },
        dismissOnClicked: true,
      ),
      MenuEntrySubMenu(
          enabled: _tempEnabled,
          text: translate('Set temporary password length'),
          entries: [
            MenuEntryRadios<String>(
                enabled: _tempEnabled,
                text: translate(''),
                optionsGetter: () => [
                      MenuEntryRadioOption(
                        text: translate('6'),
                        value: '6',
                        enabled: _tempEnabled,
                      ),
                      MenuEntryRadioOption(
                        text: translate('8'),
                        value: '8',
                        enabled: _tempEnabled,
                      ),
                      MenuEntryRadioOption(
                        text: translate('10'),
                        value: '10',
                        enabled: _tempEnabled,
                      ),
                    ],
                curOptionGetter: () async {
                  return gFFI.serverModel.temporaryPasswordLength;
                },
                optionSetter: (String oldValue, String newValue) async {
                  if (oldValue != newValue) {
                    await gFFI.serverModel.setTemporaryPasswordLength(newValue);
                    await gFFI.serverModel.updatePasswordModel();
                  }
                }),
          ])
    ];
  }

  @override
  Widget build(BuildContext context) {
    final editHover = false.obs;
    return mod_menu.PopupMenuButton(
      padding: EdgeInsets.zero,
      onHover: (v) => editHover.value = v,
      tooltip: translate(''),
      position: mod_menu.PopupMenuPosition.overSide,
      itemBuilder: (BuildContext context) => _buildMenus()
          .map((entry) => entry.build(
              context,
              const MenuConfig(
                commonColor: _MenubarTheme.commonColor,
                height: _MenubarTheme.height,
                dividerHeight: _MenubarTheme.dividerHeight,
              )))
          .expand((i) => i)
          .toList(),
      child: Obx(() => Icon(Icons.edit,
              size: 22,
              color: editHover.value
                  ? MyTheme.color(context).text
                  : const Color(0xFFDDDDDD))
          .marginOnly(bottom: 2)),
    );
  }
}
