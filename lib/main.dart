import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:marquee/marquee.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

// --- CONFIGURATION ---
const String appName = "araimo";
const String developerName = "sultanarabi161";
const String logoPath = "assets/logo.png";
const String customUserAgent = "AraimoPlayer/2.0 (Linux; Android 10) ExoPlayerLib/2.18.1";
const String configJsonUrl = "https://raw.githubusercontent.com/mxonlive/araimo/refs/heads/main/data.json";

// --- THEME COLORS ---
const Color kRed = Color(0xFFD32F2F);       // Smart Red
const Color kBlack = Color(0xFF121212);     // Background
const Color kSurface = Color(0xFF1E1E1E);   // Card Background
const Color kTextWhite = Colors.white;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AppDataProvider())],
      child: const AraimoApp(),
    ),
  );
}

class AraimoApp extends StatelessWidget {
  const AraimoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kBlack,
        primaryColor: kRed,
        colorScheme: const ColorScheme.dark(
          primary: kRed,
          surface: kSurface,
          background: kBlack,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme).apply(
          bodyColor: kTextWhite,
          displayColor: kTextWhite,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: kBlack,
          elevation: 0,
          centerTitle: true,
          scrolledUnderElevation: 0,
        ),
      ),
      home: const HomePage(),
    );
  }
}

// --- DATA LOGIC ---
class AppDataProvider extends ChangeNotifier {
  List<dynamic> allChannels = [];
  List<String> groups = ["All"];
  List<dynamic> displayedChannels = [];
  String selectedGroup = "All";
  Map<String, dynamic> config = {
    "notice": "Welcome to Araimo",
    "playlist_url": "",
    "about_notice": "",
    "telegram_url": "",
    "show_update": false
  };
  bool isLoading = true;

  AppDataProvider() {
    initApp();
  }

  Future<void> initApp() async {
    isLoading = true;
    notifyListeners();
    try {
      final res = await http.get(Uri.parse(configJsonUrl));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        config = {
          "notice": data['notice'] ?? "Welcome",
          "playlist_url": data['playlist_url'] ?? "",
          "about_notice": data['about_notice'] ?? "",
          "telegram_url": data['telegram_url'] ?? "",
          "show_update": data['update_data']?['show'] ?? false,
          "update_ver": data['update_data']?['version'] ?? "",
          "update_note": data['update_data']?['note'] ?? "",
          "dl_url": data['update_data']?['download_url'] ?? "",
        };
        if (config['playlist_url'].isNotEmpty) {
          await fetchM3U(config['playlist_url']);
        }
      }
    } catch (_) {}
    isLoading = false;
    notifyListeners();
  }

  Future<void> fetchM3U(String url) async {
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) parseM3U(res.body);
    } catch (_) {}
  }

  void parseM3U(String content) {
    final lines = LineSplitter.split(content).toList();
    List<dynamic> channels = [];
    Set<String> groupSet = {"All"};

    for (int i = 0; i < lines.length; i++) {
      if (lines[i].startsWith("#EXTINF")) {
        String info = lines[i];
        String url = (i + 1 < lines.length) ? lines[i + 1] : "";
        String name = info.split(',').last.trim();
        String group = info.contains('group-title="') ? info.split('group-title="')[1].split('"')[0] : "General";
        String logo = info.contains('tvg-logo="') ? info.split('tvg-logo="')[1].split('"')[0] : "";
        
        if (url.startsWith("http")) {
          groupSet.add(group);
          channels.add({"name": name, "group": group, "logo": logo, "url": url});
        }
      }
    }
    allChannels = channels;
    groups = groupSet.toList()..sort();
    if(groups.contains("All")) { groups.remove("All"); groups.insert(0, "All"); }
    filterChannels("All");
  }

  void filterChannels(String group) {
    selectedGroup = group;
    displayedChannels = group == "All" ? allChannels : allChannels.where((c) => c['group'] == group).toList();
    notifyListeners();
  }
}

// --- HOME PAGE ---
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppDataProvider>(context);

    return Scaffold(
      appBar: AppBar(
        leading: Padding(padding: const EdgeInsets.all(12), child: Image.asset(logoPath)),
        title: Text(appName.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, color: kRed)),
        actions: [
          IconButton(icon: const Icon(Icons.info_outline, color: Colors.white), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InfoPage()))),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator(color: kRed))
          : Column(
              children: [
                // 1. Notification Capsule with Icon
                Container(
                  margin: const EdgeInsets.all(12),
                  height: 40,
                  decoration: BoxDecoration(
                    color: kSurface,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(color: kRed, shape: BoxShape.circle),
                        child: const Icon(Icons.notifications_active, color: Colors.white, size: 20),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.only(topRight: Radius.circular(30), bottomRight: Radius.circular(30)),
                          child: Marquee(
                            text: provider.config['notice'] + "      *** ",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            velocity: 30,
                            blankSpace: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // 2. Groups
                SizedBox(
                  height: 45,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: provider.groups.length,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemBuilder: (context, index) {
                      final group = provider.groups[index];
                      final isSelected = group == provider.selectedGroup;
                      return GestureDetector(
                        onTap: () => provider.filterChannels(group),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? kRed : kSurface,
                            borderRadius: BorderRadius.circular(20),
                            border: isSelected ? null : Border.all(color: Colors.white12),
                          ),
                          alignment: Alignment.center,
                          child: Text(group, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isSelected ? Colors.white : Colors.grey)),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 10),

                // 3. Channels Grid (Logo in box + Name below)
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4, // 4 Columns
                      childAspectRatio: 0.7, // Height adjustments for Text
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 15,
                    ),
                    itemCount: provider.displayedChannels.length,
                    itemBuilder: (context, index) {
                      final channel = provider.displayedChannels[index];
                      return GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerPage(channel: channel))),
                        child: Column(
                          children: [
                            // Logo Box
                            Expanded(
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: kSurface,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white10),
                                ),
                                padding: const EdgeInsets.all(8),
                                child: CachedNetworkImage(
                                  imageUrl: channel['logo'],
                                  fit: BoxFit.contain, // Logo fits inside box perfectly
                                  errorWidget: (_,__,___) => const Icon(Icons.tv, color: Colors.grey),
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            // Channel Name Below
                            Text(
                              channel['name'],
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10, color: Colors.white70),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

// --- PLAYER PAGE (PiP Enabled, No Back Button, List Style) ---
class PlayerPage extends StatefulWidget {
  final Map<String, dynamic> channel;
  const PlayerPage({super.key, required this.channel});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late VideoPlayerController _vc;
  ChewieController? _cc;
  bool isError = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    initPlayer();
  }

  Future<void> initPlayer() async {
    try {
      _vc = VideoPlayerController.networkUrl(
        Uri.parse(widget.channel['url']),
        httpHeaders: {'User-Agent': customUserAgent}
      );
      await _vc.initialize();
      _cc = ChewieController(
        videoPlayerController: _vc,
        autoPlay: true,
        aspectRatio: 16 / 9,
        allowFullScreen: true,
        showControls: true,
        // Customizing controls to minimize clutter
        materialProgressColors: ChewieProgressColors(playedColor: kRed, handleColor: kRed),
      );
      setState(() {});
    } catch (e) {
      setState(() { isError = true; });
    }
  }

  @override
  void dispose() {
    _vc.dispose();
    _cc?.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppDataProvider>(context, listen: false);
    // Related Channels
    final related = provider.allChannels
        .where((c) => c['group'] == widget.channel['group'] && c['url'] != widget.channel['url'])
        .toList();

    return Scaffold(
      backgroundColor: kBlack,
      body: SafeArea(
        child: Column(
          children: [
            // 1. VIDEO PLAYER (No Back Button)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                color: Colors.black,
                child: isError 
                  ? const Center(child: Icon(Icons.error, color: kRed)) 
                  : (_cc != null ? Chewie(controller: _cc!) : const Center(child: CircularProgressIndicator(color: kRed))),
              ),
            ),

            // 2. INFO
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              color: kSurface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.channel['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: kRed, borderRadius: BorderRadius.circular(4)),
                    child: Text(widget.channel['group'], style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),

            // 3. RELATED CHANNELS (List Style - Beautiful)
            if (related.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text("RELATED CHANNELS", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: related.length,
                  separatorBuilder: (_,__) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = related[index];
                    return GestureDetector(
                      onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => PlayerPage(channel: item))),
                      child: Container(
                        height: 70,
                        decoration: BoxDecoration(
                          color: kSurface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          children: [
                            // Thumbnail/Logo
                            Container(
                              width: 70,
                              height: 70,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black38,
                                borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), bottomLeft: Radius.circular(10)),
                              ),
                              child: CachedNetworkImage(imageUrl: item['logo'], fit: BoxFit.contain, errorWidget: (_,__,___)=> const Icon(Icons.tv)),
                            ),
                            const SizedBox(width: 15),
                            // Name
                            Expanded(
                              child: Text(
                                item['name'],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                            // Play Icon
                            const Padding(
                              padding: EdgeInsets.only(right: 15),
                              child: Icon(Icons.play_circle_fill, color: kRed),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}

// --- INFO PAGE ---
class InfoPage extends StatelessWidget {
  const InfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final config = Provider.of<AppDataProvider>(context).config;
    return Scaffold(
      appBar: AppBar(title: const Text("Info")),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Image.asset(logoPath, height: 80),
          const SizedBox(height: 20),
          const Center(child: Text(appName, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
          Center(child: Text("Dev: $developerName", style: const TextStyle(color: kRed))),
          const SizedBox(height: 30),
          
          _tile("About", config['about_notice'], Icons.info),
          if (config['show_update'])
            _tile("Update", config['update_note'], Icons.system_update, url: config['dl_url']),
          _tile("Telegram", "Join Community", Icons.telegram, url: config['telegram_url']),
        ],
      ),
    );
  }

  Widget _tile(String title, String sub, IconData icon, {String? url}) {
    return ListTile(
      leading: Icon(icon, color: kRed),
      title: Text(title),
      subtitle: Text(sub),
      onTap: url != null ? () => launchUrl(Uri.parse(url)) : null,
      contentPadding: EdgeInsets.zero,
    );
  }
}
