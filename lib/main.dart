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
const String customUserAgent = "AraimoPlayer/3.0 (Linux; Android 10) ExoPlayerLib/2.18.1";
const String configJsonUrl = "https://raw.githubusercontent.com/mxonlive/araimo/refs/heads/main/data.json";

// --- FLAT DESIGN PALETTE ---
const Color kBgColor = Color(0xFF050505);       // Deepest Black
const Color kCardColor = Color(0xFF141414);     // Flat Grey Surface
const Color kAccentColor = Color(0xFFFF0033);   // Electric Red
const Color kTextPrimary = Color(0xFFEEEEEE);   // Off-White
const Color kTextSecondary = Color(0xFFAAAAAA); // Grey Text

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
        scaffoldBackgroundColor: kBgColor,
        primaryColor: kAccentColor,
        colorScheme: const ColorScheme.dark(
          primary: kAccentColor,
          surface: kCardColor,
          background: kBgColor,
        ),
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme).apply( // Changed to Inter font for Flat look
          bodyColor: kTextPrimary,
          displayColor: kTextPrimary,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: kBgColor,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
        ),
      ),
      home: const HomePage(),
    );
  }
}

// --- LOGIC ---
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
        if (config['playlist_url'].isNotEmpty) await fetchM3U(config['playlist_url']);
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

// --- HOME PAGE (FLAT DESIGN) ---
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppDataProvider>(context);

    return Scaffold(
      appBar: AppBar(
        leading: Padding(padding: const EdgeInsets.all(14), child: Image.asset(logoPath)),
        title: Text(appName.toUpperCase(), style: const TextStyle(fontFamily: 'GoogleFonts.bebasNeue', fontWeight: FontWeight.bold, letterSpacing: 4, color: Colors.white, fontSize: 24)),
        actions: [
          IconButton(icon: const Icon(Icons.info_outline_rounded, color: Colors.white54), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InfoPage()))),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator(color: kAccentColor, strokeWidth: 2))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. FLAT NOTIFICATION BAR
                Container(
                  width: double.infinity,
                  height: 44,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: kCardColor,
                    borderRadius: BorderRadius.circular(8), // Small radius for flat look
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        child: const Icon(Icons.notifications_none_rounded, color: kAccentColor, size: 20),
                      ),
                      Expanded(
                        child: Marquee(
                          text: provider.config['notice'] + "     ●     ",
                          style: const TextStyle(color: kTextSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                          velocity: 30,
                          blankSpace: 20,
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. CATEGORY TABS (Minimal Text)
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: provider.groups.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, index) {
                      final group = provider.groups[index];
                      final isSelected = group == provider.selectedGroup;
                      return GestureDetector(
                        onTap: () => provider.filterChannels(group),
                        child: Container(
                          margin: const EdgeInsets.only(right: 20),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: isSelected ? const Border(bottom: BorderSide(color: kAccentColor, width: 2)) : null
                          ),
                          child: Text(
                            group.toUpperCase(),
                            style: TextStyle(
                              color: isSelected ? kAccentColor : kTextSecondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 0.5
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 10),

                // 3. CHANNELS GRID (Clean & Flat)
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      childAspectRatio: 0.75,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 20,
                    ),
                    itemCount: provider.displayedChannels.length,
                    itemBuilder: (context, index) {
                      final channel = provider.displayedChannels[index];
                      return GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerPage(channel: channel))),
                        child: Column(
                          children: [
                            // Logo Container
                            Expanded(
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: kCardColor, // Flat grey background
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: CachedNetworkImage(
                                  imageUrl: channel['logo'],
                                  fit: BoxFit.contain,
                                  errorWidget: (_,__,___) => Icon(Icons.tv, color: kTextSecondary.withOpacity(0.3)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Text
                            Text(
                              channel['name'],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: kTextSecondary, fontWeight: FontWeight.w500),
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

// --- PLAYER PAGE (Clean Interface) ---
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
        materialProgressColors: ChewieProgressColors(playedColor: kAccentColor, handleColor: kAccentColor, backgroundColor: Colors.grey.shade800),
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
    final related = provider.allChannels
        .where((c) => c['group'] == widget.channel['group'] && c['url'] != widget.channel['url'])
        .toList();

    return Scaffold(
      backgroundColor: kBgColor,
      body: SafeArea(
        child: Column(
          children: [
            // VIDEO AREA
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                color: Colors.black,
                child: isError 
                  ? const Center(child: Icon(Icons.error_outline, color: kAccentColor)) 
                  : (_cc != null ? Chewie(controller: _cc!) : const Center(child: CircularProgressIndicator(color: kAccentColor))),
              ),
            ),

            // INFO AREA
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              color: kBgColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.channel['name'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: kAccentColor, borderRadius: BorderRadius.circular(4)), child: const Text("LIVE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                      const SizedBox(width: 10),
                      Text(widget.channel['group'], style: const TextStyle(color: kTextSecondary, fontSize: 12)),
                    ],
                  )
                ],
              ),
            ),

            const Divider(color: kCardColor, height: 1),

            // RELATED CHANNELS
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(0),
                itemCount: related.length,
                itemBuilder: (context, index) {
                  final item = related[index];
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => PlayerPage(channel: item))),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: kCardColor)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 50, height: 35,
                              decoration: BoxDecoration(color: kCardColor, borderRadius: BorderRadius.circular(4)),
                              padding: const EdgeInsets.all(4),
                              child: CachedNetworkImage(imageUrl: item['logo'], fit: BoxFit.contain, errorWidget: (_,__,___)=>const Icon(Icons.tv, size: 15, color: Colors.grey)),
                            ),
                            const SizedBox(width: 15),
                            Expanded(child: Text(item['name'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                            const Icon(Icons.play_arrow_rounded, color: kTextSecondary, size: 20),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- INFO PAGE (Minimal) ---
class InfoPage extends StatelessWidget {
  const InfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final config = Provider.of<AppDataProvider>(context).config;
    return Scaffold(
      appBar: AppBar(title: const Text("APP INFO", style: TextStyle(fontSize: 14, letterSpacing: 2))),
      body: ListView(
        padding: const EdgeInsets.all(30),
        children: [
          Center(child: Image.asset(logoPath, height: 70)),
          const SizedBox(height: 30),
          const Center(child: Text(appName, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -1))),
          const Center(child: Text("VERSION 1.0.0", style: TextStyle(color: kAccentColor, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold))),
          
          const SizedBox(height: 50),
          _item("Developer", developerName, null),
          _item("About", config['about_notice'], null),
          if (config['show_update']) _item("Update Available", config['update_note'], () => launchUrl(Uri.parse(config['dl_url']))),
          _item("Community", "Join Telegram", () => launchUrl(Uri.parse(config['telegram_url']))),
        ],
      ),
    );
  }

  Widget _item(String title, String sub, VoidCallback? onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 25),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title.toUpperCase(), style: const TextStyle(color: kTextSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 5),
            Row(
              children: [
                Expanded(child: Text(sub, style: TextStyle(fontSize: 14, color: onTap != null ? kAccentColor : kTextPrimary))),
                if (onTap != null) const Icon(Icons.arrow_outward, color: kAccentColor, size: 14),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
