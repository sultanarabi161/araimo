import 'dart:convert';
import 'dart:ui';
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
const String appName = "Araimo";
const String developerName = "sultanarabi161";
const String logoPath = "assets/logo.png";
const String customUserAgent = "AraimoPlayer/2.0 (Linux; Android 10) ExoPlayerLib/2.18.1";
const String configJsonUrl = "https://raw.githubusercontent.com/mxonlive/araimo/refs/heads/main/data.json";

// --- MODERN THEME PALETTE ---
const Color kPrimaryRed = Color(0xFFFF1744); // Neon Red
const Color kBackground = Color(0xFF0F0F0F); // Deep Black
const Color kSurface = Color(0xFF1C1C1E);    // Card Grey
const Color kAccent = Color(0xFF2C2C2E);     // Lighter Grey
const Color kTextWhite = Colors.white;
const Color kTextGrey = Colors.white54;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: kBackground,
  ));
  
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
        scaffoldBackgroundColor: kBackground,
        primaryColor: kPrimaryRed,
        colorScheme: const ColorScheme.dark(
          primary: kPrimaryRed,
          surface: kSurface,
          background: kBackground,
          secondary: kPrimaryRed,
        ),
        textTheme: GoogleFonts.outfitTextTheme(Theme.of(context).textTheme).apply(
          bodyColor: kTextWhite,
          displayColor: kTextWhite,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          scrolledUnderElevation: 0,
        ),
      ),
      home: const HomePage(),
    );
  }
}

// --- DATA LOGIC (UNCHANGED CORE LOGIC) ---
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
          "notice": data['notice'] ?? "Welcome to Araimo Stream",
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

// --- MODERN HOME PAGE ---
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppDataProvider>(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: provider.isLoading
          ? const LoadingScreen()
          : CustomScrollView(
              slivers: [
                // 1. Smart Sliver App Bar
                SliverAppBar(
                  floating: true,
                  pinned: true,
                  snap: false,
                  backgroundColor: kBackground.withOpacity(0.9),
                  expandedHeight: 80,
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                    title: Row(
                      children: [
                        Text(
                          appName.toUpperCase(),
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              color: kPrimaryRed,
                              fontSize: 22),
                        ),
                        const Spacer(),
                        _GlassIconButton(
                          icon: Icons.info_outline,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InfoPage())),
                        ),
                        const SizedBox(width: 16),
                      ],
                    ),
                  ),
                ),

                // 2. Breaking News / Notice Ticker
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Container(
                      height: 45,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [kSurface, kSurface.withOpacity(0.5)]),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            height: double.infinity,
                            decoration: const BoxDecoration(
                              color: kPrimaryRed,
                              borderRadius: BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
                            ),
                            child: const Icon(Icons.flash_on, color: Colors.white, size: 20),
                          ),
                          Expanded(
                            child: Marquee(
                              text: provider.config['notice'] + "      ●      ",
                              style: const TextStyle(color: kTextWhite, fontWeight: FontWeight.w600),
                              velocity: 30,
                              blankSpace: 20,
                              startAfter: const Duration(seconds: 2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 3. Category Chips (Horizontal Scroll)
                SliverToBoxAdapter(
                  child: Container(
                    height: 60,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: provider.groups.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      physics: const BouncingScrollPhysics(),
                      itemBuilder: (context, index) {
                        final group = provider.groups[index];
                        final isSelected = group == provider.selectedGroup;
                        return GestureDetector(
                          onTap: () => provider.filterChannels(group),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(right: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? kPrimaryRed : kSurface,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: isSelected 
                                ? [BoxShadow(color: kPrimaryRed.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))] 
                                : [],
                              border: Border.all(color: isSelected ? kPrimaryRed : Colors.white12),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              group,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? Colors.white : kTextGrey,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // 4. Channel Grid (Masonry/Standard Hybrid)
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final channel = provider.displayedChannels[index];
                        return ChannelCard(channel: channel);
                      },
                      childCount: provider.displayedChannels.length,
                    ),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, // 3 Columns for better visibility
                      childAspectRatio: 0.85,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                  ),
                ),
                
                // Bottom Padding
                const SliverToBoxAdapter(child: SizedBox(height: 50)),
              ],
            ),
    );
  }
}

// --- SMART CHANNEL CARD ---
class ChannelCard extends StatelessWidget {
  final Map<String, dynamic> channel;
  const ChannelCard({super.key, required this.channel});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerPage(channel: channel))),
      child: Container(
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          children: [
            // Logo Area
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Hero(
                      tag: channel['url'], // Simple unique tag
                      child: CachedNetworkImage(
                        imageUrl: channel['logo'],
                        fit: BoxFit.contain,
                        errorWidget: (_,__,___) => Icon(Icons.tv_rounded, size: 40, color: Colors.white.withOpacity(0.2)),
                      ),
                    ),
                  ),
                  // Live Badge
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: kPrimaryRed,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text("LIVE", style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            ),
            // Text Area
            Expanded(
              flex: 1,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: const BoxDecoration(
                  color: kSurface,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                ),
                alignment: Alignment.center,
                child: Text(
                  channel['name'],
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: kTextWhite),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- MODERN PLAYER PAGE ---
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
        errorBuilder: (context, errorMessage) {
          return Center(child: Text("Stream Offline", style: TextStyle(color: kPrimaryRed)));
        },
        materialProgressColors: ChewieProgressColors(playedColor: kPrimaryRed, handleColor: kPrimaryRed, backgroundColor: Colors.grey),
        cupertinoProgressColors: ChewieProgressColors(playedColor: kPrimaryRed, handleColor: kPrimaryRed),
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
      backgroundColor: kBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. VIDEO PLAYER CONTAINER
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                color: Colors.black,
                child: Stack(
                  children: [
                    isError 
                      ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.error_outline, color: kPrimaryRed, size: 40),
                          SizedBox(height: 10),
                          Text("Stream Error", style: TextStyle(color: Colors.grey))
                        ])) 
                      : (_cc != null ? Chewie(controller: _cc!) : const Center(child: CircularProgressIndicator(color: kPrimaryRed))),
                    
                    // Simple Back Button Overlay
                    Positioned(
                      top: 10,
                      left: 10,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 2. CHANNEL INFO
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: kBackground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: CachedNetworkImage(imageUrl: widget.channel['logo'], errorWidget: (_,__,___)=>Icon(Icons.tv, color: Colors.grey)),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.channel['name'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text(widget.channel['group'], style: TextStyle(fontSize: 12, color: kPrimaryRed)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 3. RELATED HEADER
            if (related.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 25, 20, 10),
                child: Text("YOU MIGHT ALSO LIKE", style: TextStyle(color: kTextGrey, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 1)),
              ),
              
              // 4. RELATED LIST (Modern List Tiles)
              Expanded(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  itemCount: related.length,
                  separatorBuilder: (_,__) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = related[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: kSurface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => PlayerPage(channel: item))),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        leading: Container(
                          width: 60,
                          height: 40,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                          child: CachedNetworkImage(imageUrl: item['logo'], fit: BoxFit.contain, errorWidget: (_,__,___)=>const Icon(Icons.tv, size: 20)),
                        ),
                        title: Text(item['name'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        trailing: const Icon(Icons.play_circle_fill_rounded, color: kPrimaryRed, size: 28),
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

// --- INFO / SETTINGS PAGE ---
class InfoPage extends StatelessWidget {
  const InfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final config = Provider.of<AppDataProvider>(context).config;
    return Scaffold(
      appBar: AppBar(title: const Text("App Info", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 20),
          Center(
            child: Container(
              height: 100, width: 100,
              decoration: BoxDecoration(
                color: kSurface,
                shape: BoxShape.circle,
                border: Border.all(color: kPrimaryRed, width: 2),
                boxShadow: [BoxShadow(color: kPrimaryRed.withOpacity(0.3), blurRadius: 20)]
              ),
              child: Image.asset(logoPath, fit: BoxFit.scaleDown),
            ),
          ),
          const SizedBox(height: 20),
          Center(child: Text(appName, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold))),
          Center(child: Text("v2.0 • Build by $developerName", style: const TextStyle(color: Colors.grey))),
          const SizedBox(height: 40),
          
          _SettingsTile(title: "About Us", sub: config['about_notice'], icon: Icons.info_rounded),
          if (config['show_update'])
            _SettingsTile(title: "Update Available", sub: "Ver: ${config['update_ver']}", icon: Icons.system_update_rounded, isHighlight: true, url: config['dl_url']),
          _SettingsTile(title: "Community", sub: "Join our Telegram", icon: Icons.telegram, url: config['telegram_url']),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String title, sub;
  final IconData icon;
  final bool isHighlight;
  final String? url;
  const _SettingsTile({required this.title, required this.sub, required this.icon, this.isHighlight = false, this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isHighlight ? kPrimaryRed.withOpacity(0.1) : kSurface,
        borderRadius: BorderRadius.circular(12),
        border: isHighlight ? Border.all(color: kPrimaryRed) : Border.all(color: Colors.white10),
      ),
      child: ListTile(
        leading: Icon(icon, color: isHighlight ? kPrimaryRed : Colors.white),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(sub, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
        onTap: url != null ? () => launchUrl(Uri.parse(url!)) : null,
      ),
    );
  }
}

// --- HELPER WIDGETS ---
class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: kPrimaryRed),
          const SizedBox(height: 20),
          Text("Getting things ready...", style: GoogleFonts.poppins(color: Colors.grey)),
        ],
      ),
    );
  }
}
