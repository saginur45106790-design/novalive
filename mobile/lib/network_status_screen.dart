import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api.dart';

class NetworkStatusScreen extends StatefulWidget {
  final Api api;
  const NetworkStatusScreen({super.key, required this.api});
  @override
  State<NetworkStatusScreen> createState() => _NetworkStatusScreenState();
}

class _NetworkStatusScreenState extends State<NetworkStatusScreen> {
  bool checking = false;
  ServerReport? report;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() => checking = true);
    final result = await widget.api.checkServer();
    if (!mounted) return;
    setState(() { report = result; checking = false; });
  }

  @override
  Widget build(BuildContext context) {
    final result = report;
    return Scaffold(
      appBar: AppBar(title: const Text('Server Connection Test')),
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('NovaLive • Network Diagnostics',
          style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        const Text('এই পেজে কোনো পাসওয়ার্ড, API Key বা Secret দেখানো হয় না।'),
        const SizedBox(height: 22),
        Card(child: Padding(padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(checking ? Icons.sync : result?.online == true
                  ? Icons.check_circle : Icons.error_outline,
                  color: checking ? Colors.amber : result?.online == true
                    ? Colors.greenAccent : Colors.orangeAccent),
              const SizedBox(width: 10),
              Expanded(child: Text(checking ? 'সার্ভারে যোগাযোগ হচ্ছে...'
                : result?.online == true ? 'সার্ভার চালু আছে' : 'সার্ভারে সংযোগ হয়নি',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
            ]),
            const SizedBox(height: 14),
            if (checking) const LinearProgressIndicator(),
            if (result != null) ...[
              Text(result.message),
              const SizedBox(height: 12),
              Text('Response: ${result.elapsed.inSeconds} seconds',
                style: const TextStyle(color: Colors.white70)),
              if (result.statusCode != null)
                Text('HTTP: ${result.statusCode}',
                  style: const TextStyle(color: Colors.white70)),
            ],
          ]))),
        const SizedBox(height: 18),
        const Text('Server Health URL', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 7),
        SelectableText('${Api.base}/health'),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: () async {
          await Clipboard.setData(ClipboardData(text: '${Api.base}/health'));
          if (context.mounted) ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('URL কপি হয়েছে')));
        }, icon: const Icon(Icons.copy), label: const Text('Health URL Copy')),
        const SizedBox(height: 12),
        ElevatedButton.icon(onPressed: checking ? null : _check,
          icon: const Icon(Icons.refresh), label: const Text('আবার পরীক্ষা করুন')),
        const SizedBox(height: 22),
        const Text('কী করবেন?',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        const Text('১. একই URL Chrome-এ খুলে ok:true দেখুন।\n'
          '২. Chrome-এ কাজ করলেও এখানে DNS Error হলে APK-এর Release INTERNET Permission যাচাই করুন।\n'
          '৩. Render Free ঘুমিয়ে থাকলে প্রথম অনুরোধ ধীর হতে পারে।\n'
          '৪. GitHub-এ API_BASE_URL বদলালে নতুন APK বিল্ড করতে হবে।'),
      ])),
    );
  }
}
