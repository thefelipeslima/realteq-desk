import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/formatter/id_formatter.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/desktop/pages/desktop_home_page.dart'
    show setPasswordDialog;
import 'package:flutter_hbb/mobile/widgets/dialog.dart' show showServerSettings;
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/server_model.dart';
import 'package:flutter_hbb/models/state_model.dart';
import 'package:flutter_hbb/realteq/rt.dart';
import 'package:flutter_hbb/realteq/version.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

/// 0 = Início, 1 = Clientes, 2 = Configurações.
final RxInt realteqNav = 0.obs;
final RxInt realteqSettingsTab = 0.obs;
final RxBool realteqSettingsUnlocked = false.obs;
const String _kAdminPassword = 'rt6603';
bool _realteqWired = false;

void _realteqWire() {
  if (_realteqWired) return;
  _realteqWired = true;
  ever<int>(realteqNav, (v) {
    if (v != 2) realteqSettingsUnlocked.value = false;
  });
}

void realteqOpenSettings({int tab = 0}) {
  realteqSettingsTab.value = tab;
  realteqNav.value = 2;
}

List<Map<String, dynamic>> realteqReadHistory() {
  try {
    final raw = bind.mainGetLocalOption(key: 'realteq-history');
    if (raw.isEmpty) return [];
    return (jsonDecode(raw) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  } catch (_) {
    return [];
  }
}

String realteqClientName(String id, [String fallback = '']) {
  final alias = bind.mainGetPeerOptionSync(id: id, key: 'alias');
  if (alias.isNotEmpty) return alias;
  return fallback.isNotEmpty ? fallback : id;
}

String realteqAgo(int ts) {
  final d = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ts));
  if (d.inMinutes < 1) return 'agora';
  if (d.inMinutes < 60) return 'há ${d.inMinutes} min';
  if (d.inHours < 24) return 'há ${d.inHours} h';
  if (d.inDays == 1) return 'ontem';
  return 'há ${d.inDays} dias';
}

/// Um cliente = todos os atendimentos do mesmo ID, do mais recente ao mais antigo.
class _Client {
  final String id;
  String name;
  int last;
  int count;
  String lastMode;
  int dur = 0;
  String note = '';
  bool fav = false;
  _Client(this.id, this.name, this.last, this.count, this.lastMode);
}

Map<String, dynamic> _readMeta() {
  try {
    final raw = bind.mainGetLocalOption(key: 'realteq-meta');
    if (raw.isEmpty) return {};
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  } catch (_) {
    return {};
  }
}

Future<void> _setMeta(String id, {String? note, bool? fav}) async {
  final m = _readMeta();
  final cur = Map<String, dynamic>.from((m[id] ?? {}) as Map);
  if (note != null) cur['note'] = note.trim();
  if (fav != null) cur['fav'] = fav;
  m[id] = cur;
  await bind.mainSetLocalOption(key: 'realteq-meta', value: jsonEncode(m));
  realteqHistoryTick.value++;
}

String _fmtDur(int s) {
  if (s <= 0) return '';
  if (s < 60) return '${s}s';
  final m = s ~/ 60;
  if (m < 60) return '$m min';
  return '${m ~/ 60} h ${m % 60} min';
}

List<_Client> _groupClients() {
  final map = <String, _Client>{};
  for (final e in realteqReadHistory()) {
    final id = (e['id'] ?? '').toString();
    if (id.isEmpty) continue;
    final ts = (e['ts'] ?? 0) as int;
    final c = map[id];
    if (c == null) {
      map[id] = _Client(id, realteqClientName(id, (e['name'] ?? '').toString()),
          ts, 1, (e['mode'] ?? '').toString())
        ..dur = (e['dur'] ?? 0) as int;
    } else {
      c.count++;
    }
  }
  final meta = _readMeta();
  for (final c in map.values) {
    final m = meta[c.id];
    if (m is Map) {
      c.note = (m['note'] ?? '').toString();
      c.fav = m['fav'] == true;
    }
  }
  return map.values.toList()
    ..sort((a, b) => a.fav != b.fav
        ? (a.fav ? -1 : 1)
        : b.last.compareTo(a.last));
}

void realteqConnectTo(BuildContext context, String raw) {
  final id = raw.replaceAll(' ', '');
  if (id.isEmpty) return;
  if (isWindows) {
    realteqAskHowToConnect(id, null, null);
  } else {
    connect(context, id);
  }
}

class RealteqShell extends StatelessWidget {
  final Widget? statusStrip;
  final VoidCallback onInstall;
  const RealteqShell({Key? key, this.statusStrip, required this.onInstall})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    _realteqWire();
    Theme.of(context);
    final dark = MyTheme.currentThemeMode() == ThemeMode.dark;
    return RtScope(
      dark: dark,
      child: Builder(builder: (context) {
        final p = context.rt;
        return Container(
          color: p.bg,
          child: Row(children: [
            _Rail(),
            Expanded(
              child: Obx(() {
                final nav = realteqNav.value;
                return Column(children: [
                  _Header(nav),
                  if (statusStrip != null) statusStrip!,
                  Expanded(
                    child: IndexedStack(index: nav, children: [
                      _HomeView(onInstall: onInstall),
                      const _ClientsView(),
                      const _SettingsView(),
                    ]),
                  ),
                ]);
              }),
            ),
          ]),
        );
      }),
    );
  }
}

class _Rail extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = context.rt;
    Widget item(IconData icon, String tip, int idx) => Obx(() => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Stack(alignment: Alignment.centerLeft, children: [
            if (realteqNav.value == idx)
              Container(
                width: 3,
                height: 22,
                decoration: BoxDecoration(
                    color: p.accent, borderRadius: BorderRadius.circular(3)),
              ),
            Center(
              child: RtIconButton(icon,
                  tooltip: tip,
                  active: realteqNav.value == idx,
                  onTap: () => realteqNav.value = idx),
            ),
          ]),
        ));
    return Container(
      width: 64,
      decoration: BoxDecoration(
          color: p.rail, border: Border(right: BorderSide(color: p.line))),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(children: [
        Image.asset('assets/realteq-crown.png',
            width: 44, filterQuality: FilterQuality.high),
        const SizedBox(height: 16),
        item(Icons.home_rounded, 'Início', 0),
        item(Icons.groups_rounded, 'Clientes', 1),
        const Spacer(),
        const _ThemeToggle(),
        const SizedBox(height: 6),
        item(Icons.tune_rounded, 'Configurações', 2),
      ]),
    );
  }
}

class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle();

  @override
  Widget build(BuildContext context) {
    final p = context.rt;
    final dark = MyTheme.currentThemeMode() == ThemeMode.dark;
    return Tooltip(
      message: dark ? 'Modo claro' : 'Modo escuro',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () =>
            MyTheme.changeDarkMode(dark ? ThemeMode.light : ThemeMode.dark),
        child: SizedBox(
          width: 44,
          height: 40,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: Icon(
              dark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
              key: ValueKey(dark),
              size: 22,
              color: p.accent,
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int nav;
  const _Header(this.nav);

  @override
  Widget build(BuildContext context) {
    final p = context.rt;
    const titles = ['Início', 'Clientes', 'Configurações'];
    final stopped = Get.isRegistered<RxBool>(tag: 'stop-service')
        ? Get.find<RxBool>(tag: 'stop-service')
        : false.obs;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
      child: Row(children: [
        Text(titles[nav],
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w600, color: p.ink)),
        const Spacer(),
        Obx(() {
          final off = stopped.value;
          final st = stateGlobal.svcStatus.value;
          final ok = !off && st == SvcStatus.ready;
          final color = ok
              ? p.ok
              : (off || st == SvcStatus.notReady ? p.danger : p.accent);
          final text = off
              ? 'Serviço parado'
              : st == SvcStatus.connecting
                  ? 'Conectando...'
                  : st == SvcStatus.notReady
                      ? 'Sem conexão com o servidor'
                      : 'Serviço ativo';
          return Row(children: [
            RtDot(color),
            const SizedBox(width: 8),
            Text(text, style: TextStyle(fontSize: 12, color: p.mut)),
          ]);
        }),
      ]),
    );
  }
}

// ---------------------------------------------------------------- Início

class _HomeView extends StatefulWidget {
  final VoidCallback onInstall;
  const _HomeView({required this.onInstall});

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  final _idCtrl = IDTextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    Get.put<IDTextEditingController>(_idCtrl);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final last = await bind.mainGetLastRemoteId();
      if (mounted && last.isNotEmpty && _idCtrl.text.isEmpty) {
        setState(() => _idCtrl.id = last);
      }
    });
  }

  @override
  void dispose() {
    if (Get.isRegistered<IDTextEditingController>()) {
      Get.delete<IDTextEditingController>();
    }
    _idCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _go() => realteqConnectTo(context, _idCtrl.id);

  @override
  Widget build(BuildContext context) {
    final p = context.rt;
    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth >= 640;
      final mine = _myAccess(p);
      final connect = _connectPanel(p);
      final pad = const EdgeInsets.all(24);
      if (wide) {
        return Padding(
          padding: pad,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 300, child: mine),
            const SizedBox(width: 20),
            Expanded(child: connect),
          ]),
        );
      }
      return SingleChildScrollView(
        padding: pad,
        child: Column(children: [mine, const SizedBox(height: 16), connect]),
      );
    });
  }

  Widget _myAccess(RtPalette p) {
    final showInstall =
        isWindows && !bind.isDisableInstallation() && !bind.mainIsInstalled();
    return ChangeNotifierProvider.value(
      value: gFFI.serverModel,
      child: Consumer<ServerModel>(builder: (context, model, _) {
        final showOneTime = model.approveMode != 'click' &&
            model.verificationMethod != kUsePermanentPassword;
        return RtPanel(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const RtLabel('Meu acesso'),
                const SizedBox(height: 10),
                SizedBox(
                  height: 46,
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: model.serverId,
                    builder: (_, v, __) => FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(v.text.isEmpty ? '— — —' : v.text,
                          style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2,
                              color: p.ink)),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(children: [
                  RtButton('Copiar ID', icon: Icons.copy_rounded, onTap: () {
                    Clipboard.setData(ClipboardData(text: model.serverId.text));
                    showToast('ID copiado');
                  }),
                  const SizedBox(width: 8),
                  RtButton('Copiar convite', icon: Icons.send_rounded, onTap: () {
                    Clipboard.setData(ClipboardData(
                        text: 'Para eu te atender, abra o Realteq Desk e me informe:\n'
                            'ID: ${model.serverId.text}\n'
                            'Senha: ${model.serverPasswd.text}'));
                    showToast('Convite copiado. Cole na conversa com o cliente.');
                  }),
                ]),
                const SizedBox(height: 18),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                      color: p.field,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: p.line)),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const RtLabel('Senha temporária'),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 28,
                              child: ValueListenableBuilder<TextEditingValue>(
                                valueListenable: model.serverPasswd,
                                builder: (_, v, __) => Text(
                                    showOneTime ? v.text : '••••••••',
                                    maxLines: 1,
                                    style: TextStyle(
                                        fontSize: 22,
                                        letterSpacing: 4,
                                        fontFamily: 'Consolas',
                                        color: showOneTime ? p.accent : p.mut)),
                              ),
                            ),
                          ]),
                    ),
                    if (showOneTime) ...[
                      RtIconButton(Icons.copy_rounded, tooltip: 'Copiar senha',
                          onTap: () {
                        Clipboard.setData(
                            ClipboardData(text: model.serverPasswd.text));
                        showToast('Senha copiada');
                      }),
                      RtIconButton(Icons.refresh_rounded,
                          tooltip: 'Gerar nova senha',
                          onTap: () => bind.mainUpdateTemporaryPassword()),
                    ],
                  ]),
                ),
                if (showInstall) ...[
                  const SizedBox(height: 18),
                  RtButton('Instalar no computador',
                      icon: Icons.download_rounded,
                      primary: true,
                      expand: true,
                      onTap: widget.onInstall),
                ],
              ]),
        );
      }),
    );
  }

  Widget _connectPanel(RtPalette p) {
    return RtPanel(
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const RtLabel('Conectar'),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _idCtrl,
                  focusNode: _focus,
                  style: TextStyle(fontSize: 16, color: p.ink),
                  inputFormatters: [IDTextInputFormatter()],
                  onSubmitted: (_) => _go(),
                  decoration: InputDecoration(
                    hintText: 'ID do computador remoto',
                    hintStyle: TextStyle(color: p.mut),
                    filled: true,
                    fillColor: p.field,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: p.line)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: p.line)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: p.accent, width: 1.5)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              RtButton('Conectar',
                  icon: Icons.arrow_forward_rounded,
                  primary: true,
                  onTap: _go),
            ]),
            const SizedBox(height: 22),
            Row(children: [
              const RtLabel('Clientes recentes'),
              const Spacer(),
              Obx(() {
                realteqHistoryTick.value;
                if (_groupClients().isEmpty) return const SizedBox();
                return InkWell(
                  onTap: _clearHistory,
                  child: Text('Limpar tudo',
                      style: TextStyle(fontSize: 12, color: p.mut)),
                );
              }),
            ]),
            const SizedBox(height: 8),
            Obx(() {
              realteqHistoryTick.value;
              final clients = _groupClients().take(6).toList();
              if (clients.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text('Nenhum atendimento ainda.',
                      style: TextStyle(color: p.mut, fontSize: 13)),
                );
              }
              return Column(children: [
                for (final c in clients) _ClientTile(c, compact: true),
              ]);
            }),
          ]),
    );
  }
}

class _ClientTile extends StatelessWidget {
  final _Client c;
  final bool compact;
  const _ClientTile(this.c, {this.compact = false});

  @override
  Widget build(BuildContext context) {
    final p = context.rt;
    final initial = c.name.isEmpty ? '?' : c.name.characters.first.toUpperCase();
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => realteqConnectTo(context, c.id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
            border: Border(top: BorderSide(color: p.line.withOpacity(0.7)))),
        child: Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
                color: p.panel2, borderRadius: BorderRadius.circular(16)),
            alignment: Alignment.center,
            child: Text(initial,
                style: TextStyle(
                    color: p.accent, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: p.ink)),
                  Text(
                      c.note.isEmpty
                          ? formatID(c.id)
                          : '${formatID(c.id)} · ${c.note}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: p.mut)),
                ]),
          ),
          Text(
              c.dur > 0
                  ? '${realteqAgo(c.last)} · ${_fmtDur(c.dur)}'
                  : realteqAgo(c.last),
              style: TextStyle(fontSize: 12, color: p.mut)),
          if (!compact) ...[
            const SizedBox(width: 14),
            Text('${c.count}x', style: TextStyle(fontSize: 12, color: p.mut)),
          ],
          Tooltip(
            message: c.fav ? 'Tirar dos favoritos' : 'Favoritar',
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _setMeta(c.id, fav: !c.fav),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(c.fav ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 17, color: c.fav ? p.accent : p.mut),
              ),
            ),
          ),
          Tooltip(
            message: 'Editar nome e nota',
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _renameClient(context, c),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(Icons.edit_rounded, size: 15, color: p.mut),
              ),
            ),
          ),
          Tooltip(
            message: 'Remover este cliente do histórico',
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _removeClient(c.id),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(Icons.close_rounded, size: 16, color: p.mut),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

Future<void> _renameClient(BuildContext context, _Client c) async {
  final p = context.rt;
  final ctrl = TextEditingController(text: c.name == c.id ? '' : c.name);
  final noteCtrl = TextEditingController(text: c.note);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: p.panel,
      title: Text('Cliente', style: TextStyle(color: p.ink, fontSize: 16)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: p.ink),
          decoration: InputDecoration(
              hintText: 'Nome. Ex.: Maria (Recepção)',
              hintStyle: TextStyle(color: p.mut),
              filled: true,
              fillColor: p.field),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: noteCtrl,
          style: TextStyle(color: p.ink),
          onSubmitted: (_) => Navigator.pop(ctx, true),
          decoration: InputDecoration(
              hintText: 'Nota. Ex.: impressora da sala 2',
              hintStyle: TextStyle(color: p.mut),
              filled: true,
              fillColor: p.field),
        ),
      ]),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: p.mut))),
        TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Salvar', style: TextStyle(color: p.accent))),
      ],
    ),
  );
  if (ok == true) {
    await realteqSaveName(c.id, ctrl.text);
    await _setMeta(c.id, note: noteCtrl.text);
  }
  ctrl.dispose();
  noteCtrl.dispose();
}

Future<void> _clearHistory() async {
  await bind.mainSetLocalOption(key: 'realteq-history', value: '');
  realteqHistoryTick.value++;
}

Future<void> _removeClient(String id) async {
  final rest = realteqReadHistory()
      .where((e) => (e['id'] ?? '').toString() != id)
      .toList();
  await bind.mainSetLocalOption(
      key: 'realteq-history', value: rest.isEmpty ? '' : jsonEncode(rest));
  realteqHistoryTick.value++;
}

// -------------------------------------------------------------- Clientes

class _ClientsView extends StatefulWidget {
  const _ClientsView();

  @override
  State<_ClientsView> createState() => _ClientsViewState();
}

class _ClientsViewState extends State<_ClientsView> {
  @override
  Widget build(BuildContext context) {
    final p = context.rt;
    return Obx(() {
    realteqHistoryTick.value;
    realteqNav.value;
    final clients = _groupClients();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: RtPanel(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const RtLabel('Todos os clientes'),
            const Spacer(),
            if (clients.isNotEmpty)
              RtButton('Limpar histórico', onTap: () async {
                await bind.mainSetLocalOption(key: 'realteq-history', value: '');
                realteqHistoryTick.value++;
              }),
          ]),
          const SizedBox(height: 10),
          Expanded(
            child: clients.isEmpty
                ? Center(
                    child: Text(
                        'Os clientes que você atender aparecem aqui,\ncom o nome que você der a eles.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: p.mut, height: 1.5)))
                : ListView(children: [
                    for (final c in clients) _ClientTile(c),
                  ]),
          ),
        ]),
      ),
    );
    });
  }
}

// --------------------------------------------------------- Configurações

class _SettingsView extends StatelessWidget {
  const _SettingsView();

  @override
  Widget build(BuildContext context) {
    return Obx(() => realteqSettingsUnlocked.value
        ? const _SettingsBody()
        : const _SettingsGate());
  }
}

class _SettingsGate extends StatefulWidget {
  const _SettingsGate();

  @override
  State<_SettingsGate> createState() => _SettingsGateState();
}

class _SettingsGateState extends State<_SettingsGate> {
  final _ctrl = TextEditingController();
  bool _wrong = false;

  void _submit() {
    if (_ctrl.text.trim() == _kAdminPassword) {
      realteqSettingsUnlocked.value = true;
    } else {
      setState(() => _wrong = true);
      _ctrl.clear();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rt;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: RtPanel(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                  color: p.panel2, borderRadius: BorderRadius.circular(16)),
              child: Icon(Icons.lock_rounded, color: p.accent, size: 24),
            ),
            const SizedBox(height: 16),
            Text('Configurações protegidas',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600, color: p.ink)),
            const SizedBox(height: 6),
            Text('Só o administrador pode alterar as configurações.\nDigite a senha para continuar.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.5, color: p.mut)),
            const SizedBox(height: 18),
            TextField(
              controller: _ctrl,
              obscureText: true,
              autofocus: true,
              onChanged: (_) {
                if (_wrong) setState(() => _wrong = false);
              },
              onSubmitted: (_) => _submit(),
              style: TextStyle(color: p.ink),
              decoration: InputDecoration(
                hintText: 'Senha do administrador',
                hintStyle: TextStyle(color: p.mut),
                errorText: _wrong ? 'Senha incorreta' : null,
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
              ),
            ),
            const SizedBox(height: 14),
            RtButton('Entrar',
                icon: Icons.lock_open_rounded,
                primary: true,
                expand: true,
                onTap: _submit),
          ]),
        ),
      ),
    );
  }
}

class _SettingsBody extends StatelessWidget {
  const _SettingsBody();

  @override
  Widget build(BuildContext context) {
    final p = context.rt;
    const cats = [
      ['Geral', 'Idioma, tema e serviço'],
      ['Segurança', 'Senhas de acesso'],
      ['Servidor', 'Conexão com o servidor'],
      ['Sobre', 'Versão do programa'],
    ];
    const icons = [
      Icons.tune_rounded,
      Icons.shield_outlined,
      Icons.dns_outlined,
      Icons.info_outline_rounded
    ];
    return Row(children: [
      Container(
        width: 210,
        decoration:
            BoxDecoration(border: Border(right: BorderSide(color: p.line))),
        padding: const EdgeInsets.all(14),
        child: Obx(() => Column(children: [
              for (var i = 0; i < cats.length; i++)
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => realteqSettingsTab.value = i,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    decoration: BoxDecoration(
                        color: realteqSettingsTab.value == i
                            ? p.panel2
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      Icon(icons[i],
                          size: 18,
                          color: realteqSettingsTab.value == i
                              ? p.accent
                              : p.mut),
                      const SizedBox(width: 10),
                      Text(cats[i][0],
                          style: TextStyle(
                              fontSize: 14,
                              color: realteqSettingsTab.value == i
                                  ? p.ink
                                  : p.mut)),
                    ]),
                  ),
                ),
            ])),
      ),
      Expanded(
        child: Obx(() {
          final i = realteqSettingsTab.value;
          return ListView(padding: const EdgeInsets.all(28), children: [
            Text(cats[i][0],
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w600, color: p.ink)),
            const SizedBox(height: 4),
            Text(cats[i][1], style: TextStyle(fontSize: 13, color: p.mut)),
            const SizedBox(height: 20),
            if (i == 0) const _GeneralSettings(),
            if (i == 1) const _SecuritySettings(),
            if (i == 2) const _ServerSettings(),
            if (i == 3) const _AboutSettings(),
          ]);
        }),
      ),
    ]);
  }
}

class _GeneralSettings extends StatefulWidget {
  const _GeneralSettings();

  @override
  State<_GeneralSettings> createState() => _GeneralSettingsState();
}

class _GeneralSettingsState extends State<_GeneralSettings> {
  @override
  Widget build(BuildContext context) {
    final lang = bind.mainGetLocalOption(key: kCommConfKeyLang);
    final isEn = lang.toLowerCase() == 'en';
    final dark = Theme.of(context).brightness == Brightness.dark;
    final stopped = Get.isRegistered<RxBool>(tag: 'stop-service')
        ? Get.find<RxBool>(tag: 'stop-service')
        : false.obs;
    return Column(children: [
      RtRow(
        title: 'Idioma',
        sub: 'Português é o padrão',
        trailing: RtSegmented(
          options: const ['Português', 'English'],
          selected: isEn ? 1 : 0,
          onSelect: (i) async {
            final key = i == 1 ? 'en' : 'pt-br';
            await bind.mainSetLocalOption(key: kCommConfKeyLang, value: key);
            await reloadAllWindows();
            bind.mainChangeLanguage(lang: key);
            if (mounted) setState(() {});
          },
        ),
      ),
      RtRow(
        title: 'Tema',
        trailing: RtSegmented(
          options: const ['Escuro', 'Claro'],
          selected: dark ? 0 : 1,
          onSelect: (i) =>
              MyTheme.changeDarkMode(i == 0 ? ThemeMode.dark : ThemeMode.light),
        ),
      ),
      Obx(() => RtRow(
            title: 'Serviço de acesso',
            sub: 'Mantém este computador disponível para suporte',
            trailing: RtToggle(
              value: !stopped.value,
              onChanged: (v) async => await start_service(v),
            ),
          )),
    ]);
  }
}

class _SecuritySettings extends StatelessWidget {
  const _SecuritySettings();

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: gFFI.serverModel,
      child: Consumer<ServerModel>(builder: (context, model, _) {
        const keys = [kUseBothPasswords, kUseTemporaryPassword, kUsePermanentPassword];
        final sel = keys.indexOf(model.verificationMethod);
        return Column(children: [
          RtRow(
            title: 'Senhas aceitas',
            sub: 'Quais senhas liberam o acesso a este computador',
            trailing: RtSegmented(
              options: const ['Ambas', 'Temporária', 'Mestra'],
              selected: sel < 0 ? 0 : sel,
              onSelect: (i) async {
                await model.setVerificationMethod(keys[i]);
                await model.updatePasswordModel();
              },
            ),
          ),
          RtRow(
            title: 'Senha mestra',
            sub: 'Senha fixa para acessos diretos',
            trailing: RtButton('Alterar', onTap: () => setPasswordDialog()),
          ),
        ]);
      }),
    );
  }
}

class _ServerSettings extends StatelessWidget {
  const _ServerSettings();

  @override
  Widget build(BuildContext context) {
    final server = bind.mainGetOptionSync(key: 'custom-rendezvous-server');
    return Column(children: [
      RtRow(
        title: 'Servidor',
        sub: server.isEmpty ? 'Padrão' : server,
        trailing: RtButton('Configurar',
            onTap: () => showServerSettings(gFFI.dialogManager, (f) => f())),
      ),
    ]);
  }
}

class _AboutSettings extends StatelessWidget {
  const _AboutSettings();

  @override
  Widget build(BuildContext context) {
    final p = context.rt;
    return Column(children: [
      RtRow(
        title: 'Realteq Desk',
        sub: 'Suporte remoto da Realteq',
        trailing: Text('v$kRealteqVersion',
            style: TextStyle(color: p.mut, fontSize: 13)),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text('Aplicativo em desenvolvimento por Felipe Lima.',
            style: TextStyle(color: p.mut, fontSize: 12)),
      ),
    ]);
  }
}
