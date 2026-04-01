import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/surah_model.dart';

class ReadingScreen extends StatefulWidget {
  final Surah surah;
  final List<Surah> allSurahs;
  final String audioBasePath;
  final int initialVerseIndex;
  
  // NEW: Should this screen start playing audio immediately?
  final bool autoPlay; 

  const ReadingScreen({
    super.key,
    required this.surah,
    required this.allSurahs,
    required this.audioBasePath,
    this.initialVerseIndex = 0,
    this.autoPlay = false, // Default to false (manual start)
  });

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ItemScrollController _itemScrollController = ItemScrollController();

  int _currentVerseIndex = -1;
  bool _isPlaying = false;
  bool _isSeeking = false;
  bool _isMuted = false;
  bool _showUI = true; 
  double _fontSize = 28.0; 

  @override
  void initState() {
    super.initState();
    _currentVerseIndex = widget.initialVerseIndex;

    _saveProgress(widget.initialVerseIndex);

    _setupAudioListeners();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 1. Scroll to saved position
      if (widget.initialVerseIndex > 0) {
        _scrollToVerse(widget.initialVerseIndex);
      }
      
      // 2. NEW: Handle Auto-Play (if coming from previous Surah)
      if (widget.autoPlay) {
        _togglePlay();
      }
    });
  }

  void _setupAudioListeners() {
    _audioPlayer.onPositionChanged.listen((Duration p) {
      if (_isSeeking) return;

      int currentMs = p.inMilliseconds;
      int newIndex = -1;
      
      for (int i = 0; i < widget.surah.verses.length; i++) {
        if (currentMs >= widget.surah.verses[i].startTime.inMilliseconds) {
          newIndex = i;
        }
      }

      if (newIndex != _currentVerseIndex && newIndex != -1) {
        setState(() {
          _currentVerseIndex = newIndex;
        });
        _scrollToVerse(newIndex);
        _saveProgress(newIndex);
      }
    });

    // CHANGED: Auto-navigate when complete
    _audioPlayer.onPlayerComplete.listen((event) {
       if (widget.surah.id < 114) {
         // If there is a next Surah, go to it immediately
         _goToNextSurah();
       } else {
         // End of Quran (Surah 114)
         setState(() {
           _isPlaying = false;
           _currentVerseIndex = -1;
           _showUI = true; 
         });
       }
    });
  }

  Future<void> _saveProgress(int verseIndex) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('global_last_surah_id', widget.surah.id);
    await prefs.setInt('surah_progress_${widget.surah.id}', verseIndex);
  }

  Future<void> _seekToVerse(int index) async {
    final verse = widget.surah.verses[index];
    await _audioPlayer.seek(verse.startTime);
    if (!_isPlaying) {
      _togglePlay(); 
    }
  }

  void _scrollToVerse(int index) {
    _itemScrollController.scrollTo(
      index: index,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      alignment: 0.2, 
    );
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      setState(() => _isPlaying = false);
    } else {
      if (_audioPlayer.state == PlayerState.paused) {
        await _audioPlayer.resume();
        setState(() => _isPlaying = true);
        return; 
      }

      final String filePath = "${widget.audioBasePath}/${widget.surah.id}.mp3";
      if (await File(filePath).exists()) {
        
        if (_currentVerseIndex > 0) {
           setState(() => _isSeeking = true); 
        }

        await _audioPlayer.play(DeviceFileSource(filePath));
        
        if (_currentVerseIndex > 0) {
           final verse = widget.surah.verses[_currentVerseIndex];
           await _audioPlayer.seek(verse.startTime);

           Future.delayed(const Duration(milliseconds: 500), () {
             if (mounted) setState(() => _isSeeking = false);
           });
        }

        await _audioPlayer.setVolume(_isMuted ? 0 : 1);
        setState(() {
           _isPlaying = true;
        });
      }
    }
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    _audioPlayer.setVolume(_isMuted ? 0 : 1);
  }

  void _toggleUI() {
    setState(() {
      _showUI = !_showUI;
    });
  }

  void _goToNextSurah() {
    int nextId = widget.surah.id + 1;
    if (nextId <= 114) {
      final nextSurah = widget.allSurahs.firstWhere((s) => s.id == nextId);
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ReadingScreen(
            surah: nextSurah,
            allSurahs: widget.allSurahs,
            audioBasePath: widget.audioBasePath,
            initialVerseIndex: 0,
            autoPlay: true, // NEW: Tell next screen to start playing!
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA), 
      body: SafeArea(
        child: Stack(
          children: [
            // --- LAYER 1: TEXT LIST ---
            ScrollablePositionedList.builder(
              itemCount: widget.surah.verses.length + 1, // Keep +1 for bottom padding
              itemScrollController: _itemScrollController,
              padding: const EdgeInsets.only(top: 70, bottom: 120), 
              itemBuilder: (context, index) {
                
                // CHANGED: Just empty space at the bottom, no button
                if (index == widget.surah.verses.length) {
                  return const SizedBox(height: 100); 
                }

                final verse = widget.surah.verses[index];
                final isActive = index == _currentVerseIndex;
                final isVerseZero = verse.id == 0;

                return InkWell(
                  onTap: _toggleUI, 
                  onDoubleTap: () => _seekToVerse(index),
                  
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFFE8F5E9) : Colors.transparent, 
                      border: isActive ? Border(right: BorderSide(color: Colors.green.shade800, width: 4)) : null,
                    ),
                    child: Text(
                      isVerseZero ? verse.text : "${verse.text} ﴿${verse.id}﴾",
                      textAlign: TextAlign.justify,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontSize: isVerseZero ? _fontSize * 0.85 : _fontSize,
                        color: isVerseZero ? const Color(0xFF2E7D32) : Colors.black87,
                        fontFamily: "Traditional Arabic",
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        height: 1.8,
                      ),
                    ),
                  ),
                );
              },
            ),

            // --- LAYER 2: TOP APP BAR ---
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              top: _showUI ? 0 : -80,
              left: 0, 
              right: 0,
              height: 60,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
                ),
                child: Row(
                  children: [
                    const BackButton(),
                    Expanded(
                      child: Text(
                        widget.surah.englishName,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    // Zoom Slider
                    SizedBox(
                      width: 100,
                      child: Slider(
                        value: _fontSize,
                        min: 20.0,
                        max: 50.0,
                        onChanged: (val) => setState(() => _fontSize = val),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // --- LAYER 3: BOTTOM CONTROLS ---
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              bottom: _showUI ? 0 : -100,
              left: 0,
              right: 0,
              height: 90,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, -2))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // REWIND 1 Verse
                    IconButton(
                      icon: const Icon(Icons.skip_previous),
                      color: Colors.grey[700],
                      iconSize: 32,
                      onPressed: () {
                        if (_currentVerseIndex > 0) {
                          _seekToVerse(_currentVerseIndex - 1);
                        } else {
                          _seekToVerse(0);
                        }
                      },
                    ),
                    
                    // PLAY / PAUSE
                    GestureDetector(
                      onTap: _togglePlay,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B5E20),
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))],
                        ),
                        child: Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),

                    // Mute
                    IconButton(
                      icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up),
                      color: Colors.grey[700],
                      iconSize: 32,
                      onPressed: _toggleMute,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}