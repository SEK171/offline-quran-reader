# 📖 The Holy Quran - Offline Reader & Player

A completely offline, ad-free, and privacy-focused Quran reading and listening application built with Flutter. 

This app was originally built as a personal project for my father and is now released for anyone who wants a distraction-free environment to read and listen to the Quran.

## Features
* **100% Offline:** Zero internet permissions required. No tracking, no ads, no data collection.
* **Precise Audio Sync:** The text highlights perfectly in sync with the audio, calibrated verse-by-verse by hand.
* **Multiple Reading Modes:** Navigate by Surah, Juz' (Parts), or Hizb (Groups) based on your reading habits.
* **Smart Resume:** Automatically remembers exactly where you left off per surah or globally. (long press a surah to restart it)
* **Customizable UI:** Adjustable font sizes and reading highlighter for following.

## How to Setup the Audio (Important!)
To keep this app completely offline and the download size small, the audio files are not bundled inside the app. **You must download them once to your phone.**

**Follow these steps:**
1. **Download the Audio:** Download the official audio `.zip` file here: `[LINK TO YOUR ARCHIVE.ORG DOWNLOAD HERE]`
2. **Extract the Files:** Unzip the downloaded file on your phone. You should now have a folder containing 114 `.mp3` files (one for each Surah).
3. **Link to the App:** Open the app. It will ask you "Where are the audio files?". Click "Select Folder", grant storage permission, and select the folder you just unzipped. (alternatively long press the logo inside the app and it will take you through the same steps for resetting the folder.


## 🛠️ Building from Source
If you want to compile the app yourself:
1. Ensure you have [Flutter](https://flutter.dev/docs/get-started/install) installed.
2. Clone this repository.
3. Run `flutter pub get` to install dependencies.
4. Run `flutter build apk` to generate the Android installation file.
