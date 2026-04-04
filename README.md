# The Holy Quran - Offline Reader & Player

A completely offline, ad-free, and privacy-focused Quran reading and listening application built with Flutter. 

This app was originally built as a personal project for my father and is now released for anyone who wants a distraction-free environment to read and listen to the Quran.

## Features
* **100% Offline:** Zero internet permissions required. No tracking, no ads, no data collection.
* **Precise Audio Sync:** The text highlights perfectly in sync with the audio, calibrated verse-by-verse by hand.
* **Multiple Reading Modes:** Navigate by Surah, Juz' (Parts), or Hizb (Groups) based on your reading habits.
* **Smart Resume:** Automatically remembers exactly where you left off globally and per Surah. *(Long press a Surah to restart it from the beginning).*
* **Customizable UI:** Adjustable font sizes and a reading highlighter for following along easily.

## How to Setup the Audio (Important!)
To keep this app completely offline and the download size small, the heavy audio files are not bundled inside the app. **You must download them once to your phone.**

>  **CRITICAL:** The verse-by-verse text highlighting timings (`quran_with_timings.json` included in this repository) were calibrated completely by hand specifically for the recitation of **Sheikh Mishary Rashid Alafasy**. You *must* use his audio files, otherwise the text highlighting will be out of sync.

**Follow these steps:**
1. **Download the Audio:** Download the official audio `.zip` file here: `[LINK TO YOUR ARCHIVE.ORG DOWNLOAD HERE]`
2. **Extract the Files:** Unzip the downloaded file on your phone. You should now have a folder containing 114 `.mp3` files (one for each Surah).
3. **Link to the App:** Open the app. It will ask you "Where are the audio files?". Click "Select Folder", grant storage permission, and select the folder you just unzipped. 
*(Alternatively, long-press the Title Bar inside the app later to reset the folder and go through these steps again).*

## Building from Source
If you want to compile the app yourself:
1. Ensure you have [Flutter](https://flutter.dev/docs/get-started/install) installed.
2. Clone this repository.
3. Run `flutter pub get` to install dependencies.
4. Run `flutter build apk` to generate the Android installation file.

## For Developers: Data & Audio Sources
* **Original Data Source:** The base Quranic text and structure was sourced from [quran-json by risan](https://github.com/risan/quran-json).
* **Calibrated Data:** The complete, hand-calibrated JSON file (`quran_with_timings.json`) is included in the `assets/json/` folder of this repository.

If you want to fetch the exact audio files directly from the source server (mp3quran.net) instead of using the Archive.org link, here is the Python script used to grab the Mishary Alafasy files:

<details>
<summary><b>Click to view the Python Audio Downloader Script</b></summary>

```python
import os
import requests

# Create the FULL path including the 'audio' folder
save_path = "quran_data/audio"
os.makedirs(save_path, exist_ok=True)

print("Starting download of 114 Surahs...")

for i in range(1, 115):
    # Pad with zeros for the URL: 1 -> "001", 14 -> "014"
    surah_id_url = f"{i:03}" 
    
    # We keep the filename simple for Flutter: "1.mp3", "2.mp3"
    filename = f"{save_path}/{i}.mp3"
    
    # URL for Sheikh Mishary Rashid Alafasy (afs)
    url = f"[https://server8.mp3quran.net/afs/](https://server8.mp3quran.net/afs/){surah_id_url}.mp3"
    
    print(f"Downloading Surah {i} from {url}...")
    
    try:
        r = requests.get(url, stream=True)
        if r.status_code == 200:
            with open(filename, 'wb') as f:
                for chunk in r.iter_content(chunk_size=1024):
                    if chunk:
                        f.write(chunk)
        else:
            print(f"Failed to download Surah {i}: Status {r.status_code}")
            
    except Exception as e:
        print(f"Error on Surah {i}: {e}")

print("Download Complete!")
