class Verse {
  final int id;
  final String text;
  final Duration startTime;
  final Duration endTime;

  Verse({
    required this.id,
    required this.text,
    required this.startTime,
    required this.endTime,
  });

  factory Verse.fromJson(Map<String, dynamic> json) {
    return Verse(
      // FIX: Change 'number' to 'id' to match your JSON file
      id: json['id'], 
      text: json['text'],
      startTime: Duration(milliseconds: json['start_ms']),
      endTime: Duration(milliseconds: json['end_ms']),
    );
  }
}

class Surah {
  final int id;
  final String arabicName;
  final String englishName;
  final List<Verse> verses;

  Surah({
    required this.id,
    required this.arabicName,
    required this.englishName,
    required this.verses,
  });

  factory Surah.fromJson(Map<String, dynamic> json) {
    var list = json['verses'] as List;
    List<Verse> verseList = list.map((i) => Verse.fromJson(i)).toList();

    return Surah(
      id: json['id'],
      arabicName: json['name'] ?? "", // The JSON has "name" for Arabic
      englishName: json['transliteration'] ?? "", // "transliteration" for English
      verses: verseList,
    );
  }
}