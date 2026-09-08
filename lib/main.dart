import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'models/surah_model.dart';
import 'reading_screen.dart';

// This acts as a global radio broadcaster for the theme color
final ValueNotifier<Color> appThemeColor = ValueNotifier(const Color(0xFF1B5E20));

void main() {
  // Boot instantly! No waiting, no crashing.
  runApp(const QuranApp());
}

class QuranApp extends StatelessWidget {
  const QuranApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ValueListenableBuilder listens to the radio broadcaster. 
    // If the color changes, it redraws the MaterialApp seamlessly.
    return ValueListenableBuilder<Color>(
      valueListenable: appThemeColor,
      builder: (context, color, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: color),
            scaffoldBackgroundColor: const Color(0xFFFAFAFA),
            useMaterial3: true,
            fontFamily: "Traditional Arabic",
          ),
          home: const HomeScreen(),
        );
      },
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
  List<dynamic> allHizb = []; 
  String? audioBasePath;
  bool isLoading = true;
  int? lastReadSurahId;
  
  late TabController _tabController;

  // The expanded elegant color palette
  final List<Color> _themeOptions = [
    const Color(0xFF1B5E20), // Classic Green
    const Color(0xFF004D40), // Dark Teal
    const Color(0xFF0D47A1), // Deep Blue
    const Color(0xFF4A148C), // Royal Purple
    const Color(0xFFB71C1C), // Deep Red
    const Color(0xFFE65100), // Burnt Orange / Amber
    const Color(0xFFF57F17), // Deep Yellow / Gold
    const Color(0xFF4E342E), // Warm Brown
    const Color(0xFF37474F), // Blue Grey
    const Color(0xFF212121), // Charcoal Black
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); 
    _initApp();
  }

  Future<void> _initApp() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPath = prefs.getString('audio_path');
    final savedSurahId = prefs.getInt('global_last_surah_id');
    
    // Check for saved color in the background
    final savedColorValue = prefs.getInt('theme_color');
    if (savedColorValue != null) {
      appThemeColor.value = Color(savedColorValue);
    }

    final String surahResponse = await rootBundle.loadString('assets/json/quran.json'); 
    final List<dynamic> surahData = json.decode(surahResponse);
    
    String juzResponse = "[]";
    try {
      juzResponse = await rootBundle.loadString('assets/json/juz_data.json');
    } catch (e) {
      print("⚠️ Error loading Juz data: $e");
    }
    
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
      allHizb = json.decode(hizbResponse); 
      lastReadSurahId = savedSurahId;
      isLoading = false;
    });
  }

  void _updateThemeColor(Color newColor) async {
    appThemeColor.value = newColor; // Broadcast the new color instantly
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_color', newColor.value); // Save it for next time
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Choose Theme Color", textAlign: TextAlign.center),
          content: Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: _themeOptions.map((color) {
              final isSelected = color.value == appThemeColor.value.value;
              return GestureDetector(
                onTap: () {
                  _updateThemeColor(color);
                  Navigator.pop(context);
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSelected 
                        ? Border.all(color: Colors.black, width: 3) 
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(2, 2),
                      )
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }
    );
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
        actions: [
          IconButton(
            icon: const Icon(Icons.color_lens),
            tooltip: 'Change Theme',
            onPressed: _showColorPicker,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          tabs: const [
            Tab(text: "Surahs"),
            Tab(text: "Juz'"),
            Tab(text: "Hizb"),
          ],
        ),
      ),
      body: Column(
        children: [
          if (lastReadSurahId != null)
             Container(
               color: appThemeColor.value.withOpacity(0.1),
               child: ListTile(
                 leading: Icon(Icons.history, color: appThemeColor.value),
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
                       leading: CircleAvatar(
                         backgroundColor: appThemeColor.value,
                         foregroundColor: Colors.white,
                         child: Text("${surah.id}")
                       ),
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

                 // --- TAB 3: HIZB ---
                 ListView.separated(
                   itemCount: allHizb.length,
                   separatorBuilder: (context, index) => const Divider(height: 1),
                   itemBuilder: (context, index) {
                     final hizb = allHizb[index];
                     return ListTile(
                       leading: CircleAvatar(
                         backgroundColor: Colors.blue[800], 
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
           
           // --- DEVELOPER CREDITS ---
           Padding(
             padding: const EdgeInsets.symmetric(vertical: 12.0),
             child: Text(
               "Developed by Salah Eddine Kourradi",
               style: TextStyle(
                 color: Colors.grey.shade600,
                 fontSize: 12,
                 fontWeight: FontWeight.w500,
                 letterSpacing: 0.5,
               ),
             ),
           ),
        ],
      ),
    );
  }
}