import 'package:cybroidos_connect/cybroidos_connect.dart';
import 'package:flutter/material.dart';

void main() => runApp(const CybroidControlApp());

class CybroidControlApp extends StatelessWidget {
  const CybroidControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cybroid Control',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const ControlHomePage(),
    );
  }
}

class ControlHomePage extends StatefulWidget {
  const ControlHomePage({super.key});

  @override
  State<ControlHomePage> createState() => _ControlHomePageState();
}

class _ControlHomePageState extends State<ControlHomePage> {
  // Stub registry: dispatch returns {"status": "unimplemented"} until the
  // KDE Connect transport is implemented in cybroidos_connect.
  final PluginRegistry _registry = PluginRegistry()
    ..register(const StubActionsPlugin())
    ..register(const StubFullscreenPlugin());

  final List<DiscoveredDevice> _devices = <DiscoveredDevice>[];
  String? _selectedDeviceId;
  String _message = 'No devices yet. Use Refresh (discovery is a stub).';

  Future<void> _refreshDevices() async {
    // Live UDP discovery exists in cybroidos_connect but is not enabled in this
    // skeleton app; keep the list empty rather than inventing devices.
    setState(() {
      _devices.clear();
      _selectedDeviceId = null;
      _message = 'No devices discovered (stub discovery).';
    });
  }

  Future<void> _pair(DiscoveredDevice device) async {
    final accepted = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => PairingPage(device: device)),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _message = accepted == true
          ? 'Pairing screen completed for ${device.name} (stub: no peer verification).'
          : 'Pairing cancelled for ${device.name}.';
    });
  }

  Future<void> _runAction(String action) async {
    if (_selectedDeviceId == null) {
      setState(() => _message = 'Select a discovered device first.');
      return;
    }
    final response = await _registry.dispatch(action);
    if (!mounted) {
      return;
    }
    setState(() {
      _message = '$_selectedDeviceId: $action -> ${response['status']} '
          '(implemented: ${response['implemented']})';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cybroid Control'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh devices',
            onPressed: _refreshDevices,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionTitle('Devices'),
            Card(
              child: _devices.isEmpty
                  ? const ListTile(
                      title: Text('No discovered devices'),
                      subtitle: Text('Discovery is not enabled in this skeleton.'),
                    )
                  : Column(
                      children: _devices.map((device) {
                        return ListTile(
                          title: Text(device.name),
                          subtitle: Text('${device.address}:${device.tcpPort}'),
                          selected: device.deviceId == _selectedDeviceId,
                          onTap: () => setState(() {
                            _selectedDeviceId = device.deviceId;
                            _message = 'Selected ${device.name}.';
                          }),
                          trailing: IconButton(
                            icon: const Icon(Icons.link),
                            tooltip: 'Pair',
                            onPressed: () => _pair(device),
                          ),
                        );
                      }).toList(),
                    ),
            ),
            const SizedBox(height: 12),
            _sectionTitle('Actions'),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _ActionTile(
                  icon: Icons.lock_outline,
                  label: 'Lock screen',
                  onTap: () => _runAction('lock'),
                ),
                _ActionTile(
                  icon: Icons.link,
                  label: 'Open URL',
                  onTap: () => _runAction('open_url'),
                ),
                _ActionTile(
                  icon: Icons.notifications_none,
                  label: 'Notification',
                  onTap: () => _runAction('notify'),
                ),
                _ActionTile(
                  icon: Icons.screen_share_outlined,
                  label: 'Full screen',
                  onTap: () => _runAction('fullscreen.start'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_message),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class PairingPage extends StatefulWidget {
  const PairingPage({super.key, required this.device});

  final DiscoveredDevice device;

  @override
  State<PairingPage> createState() => _PairingPageState();
}

class _PairingPageState extends State<PairingPage> {
  final TextEditingController _pinController = TextEditingController();
  String _hint = 'Enter the 6-digit PIN shown on the desktop.';

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _continue() {
    final pin = _pinController.text.trim();
    if (RegExp(r'^\d{6}$').hasMatch(pin) == false) {
      setState(() => _hint = 'PIN must be exactly 6 digits.');
      return;
    }
    // Skeleton: nothing is sent to the peer and no certificate is pinned.
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Pair with ${widget.device.name}')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_hint),
              const SizedBox(height: 16),
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'PIN',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _continue,
                child: const Text('Continue'),
              ),
              const SizedBox(height: 16),
              const Text(
                'v0 skeleton: this screen does not exchange keys, verify '
                'certificates or complete pairing.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
