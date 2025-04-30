import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_register_app/ConnectAPI/api_keys.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../Widget_UI/MessageWidget.dart';
import 'HomeScreen.dart';

// Main screen for Gemini without RAG
class GeneralModelScreen extends StatefulWidget {
  const GeneralModelScreen({super.key});

  @override
  State<GeneralModelScreen> createState() => _GeneralModelScreenState();
}

class _GeneralModelScreenState extends State<GeneralModelScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gemini without RAG"), // App bar title
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                'Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              title: const Text('Gemini without RAG'),
              onTap: () {
                Navigator.pop(context); // Close Drawer
              },
            ),
            ListTile(
              title: const Text('Gemini with RAG'),
              onTap: () {
                Navigator.pop(context); // Close Drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const Homescreen()),
                ); // Navigate to Homescreen
              },
            ),
          ],
        ),
      ),
      body: const ChatWidget(apiKey: GeminiConfig.apiKey), // Main chat widget
    );
  }
}

// Chat widget that interacts with Gemini model
class ChatWidget extends StatefulWidget {
  const ChatWidget({
    required this.apiKey,
    super.key,
  });

  final String apiKey; // API key for Gemini model

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> {
  late final GenerativeModel _model; // Gemini model instance
  late final ChatSession _chat; // Chat session instance
  final ScrollController _scrollController = ScrollController(); // Controller for scrolling
  final TextEditingController _textController = TextEditingController(); // Controller for input text field
  final FocusNode _textFieldFocus = FocusNode(); // Focus node for text field
  final FlutterTts _tts = FlutterTts(); // Text-to-Speech instance
  final List<({Image? image, String? text, bool fromUser})> _generatedContent = <({Image? image, String? text, bool fromUser})>[]; // Chat messages history
  bool _loading = false; // Loading state
  bool isListening = false; // Listening state for speech recognition

  @override
  void initState() {
    super.initState();
    _model = GenerativeModel(
      model: 'gemini-1.5-flash-latest',
      apiKey: widget.apiKey,
    );
    _chat = _model.startChat(); // Start a chat session
  }

  // Scroll down to the latest message
  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback(
          (_) => _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(
          milliseconds: 750,
        ),
        curve: Curves.easeOutCirc,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textFieldDecoration = InputDecoration(
      contentPadding: const EdgeInsets.all(15),
      hintText: 'Enter a prompt...', // Placeholder text
      border: OutlineInputBorder(
        borderRadius: const BorderRadius.all(
          Radius.circular(14),
        ),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(
          Radius.circular(14),
        ),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: GeminiConfig.apiKey.isNotEmpty
                ? ListView.builder(
              controller: _scrollController,
              itemBuilder: (context, idx) {
                final content = _generatedContent[idx];
                return MessageWidget(
                  text: content.text,
                  image: content.image,
                  isFromUser: content.fromUser,
                );
              },
              itemCount: _generatedContent.length,
            )
                : ListView(
              children: const [
                Text(
                  'No API key found. Please provide an API Key using '
                      "'--dart-define' to set the 'API_KEY' declaration.",
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 25,
              horizontal: 15,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    autofocus: true,
                    focusNode: _textFieldFocus,
                    decoration: textFieldDecoration,
                    controller: _textController,
                    onSubmitted: _sendChatMessage, // Send message when user submits
                  ),
                ),
                const SizedBox.square(dimension: 15),
                if (!_loading)
                  IconButton(
                    onPressed: () async {
                      _stopSpeakText();
                      final recognizedText = await _listenForSpeech();
                      _sendChatMessage(recognizedText!);
                    },
                    icon: const Icon(Icons.keyboard_voice),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                if (!_loading)
                  IconButton(
                    onPressed: !_loading
                        ? () async {
                      _stopSpeakText();
                      _sendImagePrompt(_textController.text);
                    }
                        : null,
                    icon: Icon(
                      Icons.image,
                      color: _loading
                          ? Theme.of(context).colorScheme.secondary
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                if (!_loading)
                  IconButton(
                    onPressed: () async {
                      _stopSpeakText();
                      _sendChatMessage(_textController.text);
                    },
                    icon: Icon(
                      Icons.send,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  )
                else
                  const CircularProgressIndicator(), // Show loading indicator if loading
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Listen for speech input and return recognized text
  Future<String?> _listenForSpeech() async {
    final SpeechToText speechToText = SpeechToText();

    final bool available = await speechToText.initialize();
    if (!available) {
      print('Speech recognition not available.');
      return null;
    }

    String? recognizedText;
    isListening = true;
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Text('Listening...'), // Show dialog while listening
        );
      },
    );

    speechToText.listen(
      localeId: 'th-TH', // Set language to Thai
      onResult: (val) {
        if (val.recognizedWords.isNotEmpty) {
          recognizedText = val.recognizedWords;
          print('Recognized text: $recognizedText');
        } else {
          print('No recognized text.');
        }
        _stopListenForSpeech();
      },
    );

    await Future.delayed(const Duration(seconds: 9)); // Timeout after 9 seconds
    _stopListenForSpeech();
    return recognizedText;
  }

  // Stop listening for speech
  Future<void> _stopListenForSpeech() async {
    final SpeechToText speechToText = SpeechToText();
    if (isListening) {
      isListening = false;
      Navigator.of(context).pop(); // Close listening dialog
      await speechToText.stop();
    }
  }

  // Send an image prompt with a text input
  Future<void> _sendImagePrompt(String message) async {
    setState(() {
      _loading = true;
    });
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final bytes = await image.readAsBytes();
        final content = [
          Content.multi([
            TextPart(message),
            DataPart('image/jpeg', bytes),
          ])
        ];
        _generatedContent.add((
        image: Image.file(File(image.path)),
        text: message,
        fromUser: true
        ));

        var response = await _model.generateContent(content);
        var text = response.text;
        _generatedContent.add((image: null, text: text, fromUser: false));

        if (text == null) {
          _showError('No response from API.');
          return;
        } else {
          setState(() {
            _loading = false;
            _scrollDown();
          });
        }
      } else {
        _showError('No image selected.');
      }
    } catch (e) {
      _showError(e.toString());
      setState(() {
        _loading = false;
      });
    } finally {
      _textController.clear();
      setState(() {
        _loading = false;
      });
      _textFieldFocus.requestFocus();
    }
  }

  // Send a text chat message
  Future<void> _sendChatMessage(String message) async {
    setState(() {
      _loading = true;
    });

    try {
      _generatedContent.add((image: null, text: message, fromUser: true));
      final response = await _chat.sendMessage(
        Content.text(message),
      );
      final text = response.text;
      _generatedContent.add((image: null, text: text, fromUser: false));
      _speakText(text!); // Speak the model's response

      setState(() {
        _loading = false;
        _scrollDown();
      });
    } catch (e) {
      _showError(e.toString());
      setState(() {
        _loading = false;
      });
    } finally {
      _textController.clear();
      setState(() {
        _loading = false;
      });
      _textFieldFocus.requestFocus();
    }
  }

  // Speak the given text using Text-to-Speech
  Future<void> _speakText(String texts) async {
    final tts = FlutterTts();
    await tts.setLanguage('th-TH');
    await tts.setSpeechRate(1);
    await tts.speak(texts);
  }

  // Stop speaking
  Future<void> _stopSpeakText() async {
    await _tts.stop();
  }

  // Show an error dialog with a message
  void _showError(String message) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Something went wrong'),
          content: SingleChildScrollView(
            child: SelectableText(message),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            )
          ],
        );
      },
    );
  }
}
