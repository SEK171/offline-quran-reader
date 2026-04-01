import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'models/surah_model.dart';
import 'reading_screen.dart';

void main() {
  runApp(const QuranApp());
}

class QuranApp extends StatelessWidget {
  const QuranApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B5E20)),
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
        useMaterial3: true,
        fontFamily: "Traditional Arabic",
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  List<Surah> allSurahs = [];
  List<dynamic> allJuz = [];
  List<dynamic> allHizb = []; // NEW: Hizb Data
  String? audioBasePath;
  bool isLoading = true;
  int? lastReadSurahId;
  
  // Update TabController length to 3
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // CHANGED TO 3
    _initApp();
  }

  Future<void> _initApp() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPath = prefs.getString('audio_path');
    final savedSurahId = prefs.getInt('global_last_surah_id');

    // 1. Load Surahs
    final String surahResponse = await rootBundle.loadString('assets/json/quran.json'); 
    final List<dynamic> surahData = json.decode(surahResponse);
    
    // 2. Load Juz Data
    String juzResponse = "[]";
    try {
      juzResponse = await rootBundle.loadString('assets/json/juz_data.json');
    } catch (e) {
      print("⚠️ Error loading Juz data: $e");
    }
    
    // 3. Load Hizb Data (NEW)
    String hizbResponse = "[]";
    try {
      hizbResponse = await rootBundle.loadString('assets/json/hizb_data.json');
    } catch (e) {
      print("⚠️ Error loading Hizb data: $e");
    }

    setState(() {
      audioBasePath = savedPath;
      allSurahs = surahData.map((json) => Surah.fromJson(json)).toList();
      allJuz = json.decode(juzResponse);
      allHizb = json.decode(hizbResponse); // Load the JSON
      lastReadSurahId = savedSurahId;
      isLoading = false;
    });
  }

  Future<void> _openSurah(int surahId, {int startVerseId = 0, bool forceRestart = false}) async {
    final surah = allSurahs.firstWhere((s) => s.id == surahId);
    int targetIndex = 0;

    if (forceRestart) {
       targetIndex = 0;
    } else if (startVerseId > 0) {
      targetIndex = surah.verses.indexWhere((v) => v.id == startVerseId);
      if (targetIndex == -1) targetIndex = 0;
    } else {
      final prefs = await SharedPreferences.getInstance();
      targetIndex = prefs.getInt('surah_progress_${surah.id}') ?? 0;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReadingScreen(
          surah: surah,
          allSurahs: allSurahs,
          audioBasePath: audioBasePath!,
          initialVerseIndex: targetIndex,
          autoPlay: startVerseId > 0, 
        ),
      ),
    ).then((_) {
      _initApp(); 
    });
  }

  Future<void> _pickAudioFolder() async {
    if (await Permission.manageExternalStorage.isGranted) {
    } else {
      await Permission.manageExternalStorage.request();
      if (!await Permission.storage.isGranted) {
        await Permission.storage.request();
      }
    }

    if (await Permission.manageExternalStorage.isGranted || await Permission.storage.isGranted) {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('audio_path', selectedDirectory);
        setState(() {
          audioBasePath = selectedDirectory;
        });
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Storage permission is required.")),
        );
      }
    }
  }

  Future<void> _resetFolder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('audio_path');
    setState(() {
      audioBasePath = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    if (audioBasePath == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Setup Audio")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.folder_off, size: 80, color: Colors.grey),
              const SizedBox(height: 20),
              const Text("Where are the audio files?", style: TextStyle(fontSize: 20)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _pickAudioFolder,
                icon: const Icon(Icons.folder_open),
                label: const Text("Select Folder"),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onLongPress: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text("Reset Folder?"),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                  TextButton(
                    onPressed: () { Navigator.pop(ctx); _resetFolder(); },
                    child: const Text("Reset", style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );
          },
          child: const Text("The Holy Quran"),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: TabBar(
          controller: _tabController,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          tabs: const [
            Tab(text: "Surahs"),
            Tab(text: "Juz'"),
            Tab(text: "Hizb"), // NEW TAB
          ],
        ),
      ),
      body: Column(
        children: [
          if (lastReadSurahId != null)
             Container(
               color: Colors.green[50],
               child: ListTile(
                 leading: const Icon(Icons.history, color: Colors.green),
                 title: const Text("Continue Reading"),
                 subtitle: Text("Surah ${allSurahs[lastReadSurahId! - 1].englishName}"),
                 trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                 onTap: () {
                   _openSurah(lastReadSurahId!);
                 },
               ),
             ),
             
           Expanded(
             child: TabBarView(
               controller: _tabController,
               children: [
                 // --- TAB 1: SURAHS ---
                 ListView.separated(
                   itemCount: allSurahs.length,
                   separatorBuilder: (context, index) => const Divider(height: 1),
                   itemBuilder: (context, index) {
                     final surah = allSurahs[index];
                     return ListTile(
                       leading: CircleAvatar(child: Text("${surah.id}")),
                       title: Text(
                         surah.arabicName,
                         style: const TextStyle(fontSize: 22, fontFamily: "Traditional Arabic"),
                         textAlign: TextAlign.right,
                       ),
                       subtitle: Text(surah.englishName),
                       onLongPress: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text("Restart ${surah.englishName}?"),
                              content: const Text("Start from the beginning?"),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                                TextButton(
                                  onPressed: () { 
                                    Navigator.pop(ctx); 
                                    _openSurah(surah.id, forceRestart: true); 
                                  },
                                  child: const Text("Restart"),
                                ),
                              ],
                            ),
                          );
                       },
                       onTap: () => _openSurah(surah.id),
                     );
                   },
                 ),

                 // --- TAB 2: JUZ ---
                 ListView.separated(
                   itemCount: allJuz.length,
                   separatorBuilder: (context, index) => const Divider(height: 1),
                   itemBuilder: (context, index) {
                     final juz = allJuz[index];
                     return ListTile(
                       leading: CircleAvatar(
                         backgroundColor: Colors.orange[800], 
                         foregroundColor: Colors.white,
                         child: Text("${juz['id']}"),
                       ),
                       title: Text(
                         juz['name_ar'],
                         style: const TextStyle(fontSize: 22, fontFamily: "Traditional Arabic"),
                         textAlign: TextAlign.right,
                       ),
                       subtitle: Text("${juz['name_en']}\n${juz['desc']}", maxLines: 2),
                       isThreeLine: true,
                       onTap: () {
                         _openSurah(juz['start_surah'], startVerseId: juz['start_verse']);
                       },
                     );
                   },
                 ),

                 // --- TAB 3: HIZB (NEW) ---
                 ListView.separated(
                   itemCount: allHizb.length,
                   separatorBuilder: (context, index) => const Divider(height: 1),
                   itemBuilder: (context, index) {
                     final hizb = allHizb[index];
                     return ListTile(
                       leading: CircleAvatar(
                         backgroundColor: Colors.blue[800], // Blue for Hizb
                         foregroundColor: Colors.white,
                         child: Text("${hizb['id']}"),
                       ),
                       title: Text(
                         hizb['name_ar'],
                         style: const TextStyle(fontSize: 22, fontFamily: "Traditional Arabic"),
                         textAlign: TextAlign.right,
                       ),
                       subtitle: Text("Surah ${hizb['start_surah']}, Verse ${hizb['start_verse']}"),
                       onTap: () {
                         _openSurah(hizb['start_surah'], startVerseId: hizb['start_verse']);
                       },
                     );
                   },
                 ),
               ],
             ),
           ),
        ],
      ),
    );
  }
}