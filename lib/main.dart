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

// --- APP CONFIG ---
const String appName = "araimo";
const String developerName = "sultanarabi161";
const String logoPath = "assets/logo.png";
const String customUserAgent = "AraimoPlayer/4.0 (Linux; Android 10) ExoPlayerLib/2.18.1";
const String configJsonUrl = "https://raw.githubusercontent.com/mxonlive/araimo/refs/heads/main/data.json";

// --- CLASSIC MODERN PALETTE ---
const Color kBgColor = Color(0xFF121212);        // Rich Dark Background
const Color kSurfaceColor = Color(0xFF1E2228);   // Soft Blue-Grey Surface
const Color kAccentColor = Color(0xFFE50914);    // Classic Sports Red
const Color kTextPrimary = Color(0xFFF5F5F5);    // White Smoke
const Color kTextSecondary = Color(0xFF9E9E9E);  // Grey

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
          surface: kSurfaceColor,
          background: kBgColor,
        ),
        // Using 'Rubik' for a sturdy, modern sports feel
        textTheme: GoogleFonts.rubikTextTheme(Theme.of(context).textTheme).apply(
          bodyColor: kTextPrimary,
          displayColor: kTextPrimary,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: kBgColor,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: kTextPrimary),
        ),
      ),
      home: const HomePage(),
    );
  }
}

// --- DATA PROVIDER ---
class AppDataProvider extends ChangeNotifier {
  List<dynamic> allChannels = [];
  List<String> groups = ["All"];
  List<dynamic> displayedChannels = [];
  String selectedGroup = "All";
  Map<String, dynamic> config = {
    "notice": "Loading updates...",
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
          "notice": data['notice'] ?? "Welcome to Araimo",
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

// --- HOME PAGE (Classic Modern) ---
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppDataProvider>(context);

    return Scaffold(
      appBar: AppBar(
        leading: Padding(padding: const EdgeInsets.all(12), child: Image.asset(logoPath)),
        title: Text(
          appName.toUpperCase(), 
          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 3, fontSize: 22)
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline), 
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InfoPage()))
          ),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator(color: kAccentColor))
          : Column(
              children: [
                // 1. NEWS TICKER STYLE NOTICE
                Container(
                  width: double.infinity,
                  height: 36,
                  color: kSurfaceColor, // Full width strip
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        height: 36,
                        color: kAccentColor,
                        alignment: Alignment.center,
                        child: const Icon(Icons.campaign, color: Colors.white, size: 20),
                      ),
                      Expanded(
                        child: Marquee(
                          text: provider.config['notice'] + "      •      ",
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: kTextPrimary),
                          velocity: 30,
                          blankSpace: 20,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // 2. CATEGORIES (Pill Style)
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: provider.groups.length,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemBuilder: (context, index) {
                      final group = provider.groups[index];
                      final isSelected = group == provider.selectedGroup;
                      return GestureDetector(
                        onTap: () => provider.filterChannels(group),
                        child: Container(
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: isSelected ? kTextPrimary : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isSelected ? kTextPrimary : kTextSecondary.withOpacity(0.5)),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            group, 
                            style: TextStyle(
                              color: isSelected ? kBgColor : kTextSecondary,
                              fontWeight: FontWeight.bold, 
                              fontSize: 12
                            )
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 10),

                // 3. GRID CONTENT
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      childAspectRatio: 0.70,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: provider.displayedChannels.length,
                    itemBuilder: (context, index) {
                      final channel = provider.displayedChannels[index];
                      return GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerPage(channel: channel))),
                        child: Column(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: kSurfaceColor,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))
                                  ]
                                ),
                                padding: const EdgeInsets.all(10),
                                child: CachedNetworkImage(
                                  imageUrl: channel['logo'],
                                  fit: BoxFit.contain,
                                  errorWidget: (_,__,___) => Icon(Icons.tv, color: kTextSecondary.withOpacity(0.3)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              channel['name'],
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: kTextSecondary),
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

// --- PLAYER PAGE ---
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
        materialProgressColors: ChewieProgressColors(playedColor: kAccentColor, handleColor: kAccentColor),
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
            // VIDEO
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                color: Colors.black,
                child: isError 
                  ? const Center(child: Icon(Icons.error_outline, color: kAccentColor)) 
                  : (_cc != null ? Chewie(controller: _cc!) : const Center(child: CircularProgressIndicator(color: kAccentColor))),
              ),
            ),

            // CHANNEL INFO
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: kSurfaceColor))
              ),
              child: Row(
                children: [
                  Container(
                    width: 45, height: 45,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(color: kSurfaceColor, borderRadius: BorderRadius.circular(8)),
                    child: CachedNetworkImage(imageUrl: widget.channel['logo'], fit: BoxFit.contain, errorWidget: (_,__,___)=>const Icon(Icons.tv)),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.channel['name'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text("● LIVE  |  ${widget.channel['group']}", style: const TextStyle(fontSize: 11, color: kAccentColor, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // RELATED HEADER
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 15, 20, 10),
              color: kBgColor,
              child: const Text("UP NEXT", style: TextStyle(color: kTextSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),

            // RELATED LIST
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: related.length,
                separatorBuilder: (_,__) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = related[index];
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => PlayerPage(channel: item))),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: kSurfaceColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 40, 
                              child: CachedNetworkImage(imageUrl: item['logo'], fit: BoxFit.contain, errorWidget: (_,__,___)=>const Icon(Icons.tv, size: 16, color: Colors.grey)),
                            ),
                            const SizedBox(width: 15),
                            Expanded(child: Text(item['name'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                            const Icon(Icons.play_circle_outline, color: kTextSecondary, size: 22),
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

// --- INFO PAGE ---
class InfoPage extends StatelessWidget {
  const InfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final config = Provider.of<AppDataProvider>(context).config;
    return Scaffold(
      appBar: AppBar(title: const Text("Information")),
      body: ListView(
        padding: const EdgeInsets.all(25),
        children: [
          Center(child: Image.asset(logoPath, height: 90)),
          const SizedBox(height: 25),
          const Center(child: Text(appName, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 2))),
          const Center(child: Text("VERSION 1.0.0", style: TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 3))),
          const SizedBox(height: 40),
          
          _sectionTitle("DEVELOPER"),
          _infoTile(Icons.code, developerName, null),
          
          const SizedBox(height: 20),
          _sectionTitle("ABOUT"),
          _infoTile(Icons.info_outline, config['about_notice'], null),
          
          if (config['show_update']) ...[
            const SizedBox(height: 20),
            _sectionTitle("UPDATES"),
            _infoTile(Icons.system_update, config['update_note'], () => launchUrl(Uri.parse(config['dl_url']))),
          ],
          
          const SizedBox(height: 20),
          _sectionTitle("COMMUNITY"),
          _infoTile(Icons.telegram, "Join Official Channel", () => launchUrl(Uri.parse(config['telegram_url']))),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 5),
      child: Text(title, style: const TextStyle(color: kAccentColor, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _infoTile(IconData icon, String text, VoidCallback? onTap) {
    return Container(
      decoration: BoxDecoration(color: kSurfaceColor, borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: Icon(icon, color: kTextPrimary, size: 20),
        title: Text(text, style: const TextStyle(fontSize: 14)),
        trailing: onTap != null ? const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey) : null,
        onTap: onTap,
      ),
    );
  }
}
