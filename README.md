# Research Title

RMUTTOBot: Transforming University Admission Services with a RAG-Based LLM Chatbot

## Description

RMUTTOBot is an intelligent chatbot system designed to enhance and streamline university admission services at Rajamangala University of Technology Tawan-Ok (RMUTTO). Built using Retrieval-Augmented Generation (RAG) integrated with Large Language Models (LLMs), the bot provides accurate, real-time responses to admission-related inquiries by leveraging structured data sources. This project aims to reduce administrative workload, improve student support, and modernize service delivery through a conversational AI interface. RMUTTOBot is developed using Flutter for cross-platform support, Gemini 1.5 Flash for LLM capabilities, and Firebase for backend services.

## Getting Started

### Dependencies

* Flutter SDK (>=3.16.0)
* Dart (>=3.2.0)
* Firebase CLI
* Android Studio or Xcode (for emulators or physical device deployment)
* PyCharm

### Installing

1. Clone the repository
```
git clone https://github.com/vipa-thananant/RMUTTOBot.git
cd RMUTTOBot
```
2. Install dependencies
```
flutter pub get
```
3. Set up Firebase
   
* Create a Firebase project at https://console.firebase.google.com
* Download the google-services.json (Android) or GoogleService-Info.plist (iOS) and place them in the correct directories (android/app or ios/Runner)

4. Set up API variables for Gemini API and Firebase
 * Replace your own API in class GeminiConfig
```
class GeminiConfig {
  static const String apiKey = "your Gemini api key here";
}
class Config {
  static const String apiKey = "Firebase API key here";
  static const String authDomain = "Firebase domain here";
  static const String projectId = "Firebase projectID here";
  static const String storageBucket = "Firebase storageBucket here";
  static const String messagingSenderId = "id here";
  static const String appId = "app id here";
}
```
### Executing program
To run the chatbot:
1. Run python 
* Run main.py in PyCharm
* Run FastAPI server type command
```
uvicorn main:app –reload
```
2. Rewrite the logic in HomeScreen.dart to ensure it always loads data from Firebase instead of mock data, using useFirebase: true.
```
if (allFaqList.isEmpty)
   {
      // Load FAQ data if it hasn't been loaded yet
      await loadFaqDataOnce(useFirebase: true);
   }
```   
3. Run Flutter   
```
flutter run
```
## Help
For common issues:
* Ensure all Firebase dependencies are correctly initialized.
* Check the internet connection if the chatbot doesn’t respond.
* Use this command for general Flutter diagnostics:
```
flutter doctor
```

## Authors
Vipa Thananant
Contact: vipa_th@rmutto.ac.th

## Version History

* 0.1
    * Initial Release

## License

This project is licensed under the MIT License - see the LICENSE.md file for details.

