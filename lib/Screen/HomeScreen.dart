import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_register_app/Screen/General_Modle_Screen.dart';
import 'package:flutter_register_app/ConnectAPI/api_keys.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:http/http.dart' as http;
import '../Widget_UI/MessageWidget.dart';
import 'MatchResult.dart';
// Define the Homescreen widget
class Homescreen extends StatefulWidget {
  const Homescreen({super.key});

  @override
  State<Homescreen> createState() => _HomescreenState();
}
// Define the state for Homescreen
class _HomescreenState extends State<Homescreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gemini with RAG"),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Drawer header
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
            // Drawer list items
            ListTile(
              title: const Text('Gemini without RAG'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const GeneralModelScreen()),
                );
              },
            ),
            ListTile(
              title: const Text('Gemini with RAG'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      body: const ChatWidget(apiKey: GeminiConfig.apiKey),
    );
  }
}
// Define the ChatWidget
class ChatWidget extends StatefulWidget {
  const ChatWidget({
    required this.apiKey,
    super.key,
  });

  final String apiKey;

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}
// Define the state for ChatWidget
class _ChatWidgetState extends State<ChatWidget> {
  late final ScrollController _scrollController;
  late final TextEditingController _textController;
  late final FocusNode _textFieldFocus;
  late final FlutterTts _tts;
  late final SpeechToText _speechToText;
  late final ImagePicker _picker;
  late final GenerativeModel _model;
  late final ChatSession _chat;
  bool _loading = false;
  List<Map<String, dynamic>> allFaqList = [];
  final List<({Image? image, String? text, bool fromUser})> _generatedContent =
  <({Image? image, String? text, bool fromUser})>[];

  @override
  void initState() {
    super.initState();
    // Initialize controllers and models
    _scrollController = ScrollController();
    _textController = TextEditingController();
    _textFieldFocus = FocusNode();
    _tts = FlutterTts();
    _speechToText = SpeechToText();
    _picker = ImagePicker();
    _model = GenerativeModel(
      model: 'gemini-1.5-flash-latest',
      apiKey: widget.apiKey,
    );
    _chat = _model.startChat();
  }

  Future<void> loadFaqDataOnce({bool useFirebase = true}) async {
    if (useFirebase) {
      // Firebase Firestore instance initialization
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      CollectionReference faqCollection = firestore.collection('FAQ');

      // Fetching FAQ data from Firebase Firestore
      QuerySnapshot querySnapshot = await faqCollection.get();
      allFaqList = querySnapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } else {
      // Using mock data instead of Firebase
      allFaqList = [
        {
          "คำถาม": "มหาวิทยาลัยตั้งอยู่ที่ไหน",
          "คำตอบ": "มีวิทยาเขตหลักในจังหวัดชลบุรี และวิทยาเขตอื่นๆ ในกรุงเทพ และ จันทบุรี",
        },
        {
          "คำถาม": "การสมัครเรียนต้องใช้เอกสารอะไรบ้าง",
          "คำตอบ": "สำเนาบัตรประชาชน  ปพ.1  รูปถ่าย",
        },
        {
          "คำถาม": "เอกสารที่ต้องใช้ในการสมัครมีอะไรบ้าง",
          "คำตอบ": "สำเนาบัตรประชาชน สำเนาทะเบียนบ้าน ปพ.1 และรูปถ่าย",
        },
        {
          "คำถาม": "ทุนเรียนดีมีอะไรบ้าง",
          "คำตอบ": "มีทุนสำหรับนักศึกษาที่มีผลการเรียนดี เช่น ทุนพระราชทาน และทุนสนับสนุนจากองค์กรภายนอก",
        },
        {
          "คำถาม": "เปิดรับสมัครชั้นอะไรบ้าง",
          "คำตอบ": "ปริญญาตรี โท และ เอก",
        },
        {
          "คำถาม": "รอบการรับสมัครมีช่วงไหนบ้าง",
          "คำตอบ": "ปกติรอบแรกเริ่ม ตุลาคม - ธันวาคม และมีรอบเพิ่มเติม",
        },
        {
          "คำถาม": "สามารถสมัครเรียนผ่านช่องทางไหนได้บ้าง",
          "คำตอบ": "สมัครผ่าน TCAS, การสอบตรง, และโควตาพิเศษ",
        },
        {
          "คำถาม": "ทุนการศึกษาต้องใช้เอกสารอะไรบ้าง",
          "คำตอบ": "สำเนาบัตรประชาชน ใบแสดงผลการเรียน (ปพ.1)  หนังสือรับรองรายได้ และเอกสารอื่นๆ ตามเงื่อนไขของทุน",
        },
        {
          "คำถาม": "ต้องใช้คะแนนสอบอะไรบ้างในการสมัคร",
          "คำตอบ": "ขึ้นอยู่กับคณะและสาขาที่เลือกเรียน บางคณะอาจต้องใช้คะแนนสอบ O-NET หรือ GAT/PAT",
        },
        {
          "คำถาม": "มหาวิทยาลัยมีกิจกรรมทางวิชาการอะไรบ้าง",
          "คำตอบ": "มีการจัดงานสัมมนา การประกวดผลงานวิจัย การแข่งการนำเสนอผลงานวิชาการ และการเข้าร่วมโครงการสหกิจศึกษา",
        },
        {
          "คำถาม": "ใช้คะแนนสอบอะไรบ้าง",
          "คำตอบ": "ใช้คะแนน GAT/PAT หรือ O-NET ตามสาขาวิชา",
        },
        {
          "คำถาม": "มหาวิทยาลัย มีทั้งหมดกี่คณะ",
          "คำตอบ": "มี 7 คณะ ได้แก่ คณะเกษตรศาสตร์และทรัพยากรธรรมชาติ คณะบริหารธุรกิจและเทคโนโลยีสารสนเทศ คณะวิศวกรรมศาสตร์และเทคโนโลยี คณะศิลปะศาสตร์ คณะสัตวแพทยศาสตร์ คณะวิทยาศาสตร์และเทคโนโลยี คณะอุตสาหกรรมเกษตร",
        },
        {
          "คำถาม": "มหาวิทยาลัยเปิดสอนในระบบไหน",
          "คำตอบ": "มีทั้ง ภาคปกติ (จันทร์-ศุกร์) ภาคพิเศษ (เสาร์-อาทิตย์) และ ภาคค่ำ (จันทร์-ศุกร์)",
        },
        {
          "คำถาม": "มหาวิทยาลัย ก่อตั้งเมื่อไหร่",
          "คำตอบ": "ก่อตั้งเมื่อปี 2548",
        },
        {
          "คำถาม": "มหาวิทยาลัย มีโควตาสำหรับนักเรียนในพื้นที่หรือไม่",
          "คำตอบ": "มีโควตาสำหรับนักเรียน ภาคตะวันออก",
        },
      ];
    }
  }

// Fetch relevant FAQ data based on user query
  Future<String> getFaqData(String query) async {
    // Check if FAQ data is empty
    if (allFaqList.isEmpty) {
      // Load FAQ data if it hasn't been loaded yet
      await loadFaqDataOnce(useFirebase: false);
    }

    // Extract a list of all FAQ questions from the loaded data
    List<String> questionList = allFaqList.map((item) => item['คำถาม'] as String).toList();

    // Get a list of top matching questions based on the user query
    List<MatchResult> matches = await getTopMatches(query, questionList);

    // Extract the matched questions into a set to remove duplicates
    Set<String> topQuestions = matches.map((m) => m.question).toSet();

    // Filter the full FAQ list to include only the matched questions
    List<Map<String, dynamic>> newFaqList = allFaqList
        .where((faq) => topQuestions.contains(faq['คำถาม']))
        .toList();
    // Convert the filtered FAQ list to JSON string and return
    return jsonEncode(newFaqList);
  }
// Send request to the local matching server
  Future<List<MatchResult>> getTopMatches(String query, List<String> candidates) async {
    // Define the URL of the matching service API
    final url = Uri.parse('http://127.0.0.1:8000/match');

    // Send a POST request to the API with the query and candidate list
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json; charset=UTF-8'}, // Set the content type to JSON
      body: jsonEncode({
        'query': query,               // The input query from the user
        'candidates': candidates,     // List of possible questions to match against
        'top_n': 10                   // Number of top matches to return
      }),
    );

    // If the request is successful (status code 200)
    if (response.statusCode == 200) {
      // Decode the JSON response body
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      // Extract the list of matched results from the response
      final List<dynamic> matches = decoded['top_matches'];

      // Convert each match JSON object into a MatchResult object and return the list
      return matches.map((m) => MatchResult.fromJson(m)).toList();
    } else {
      // If the API call fails, throw an exception
      throw Exception('Failed to fetch matches');
    }
  }
  // Handle sending chat message with FAQ data
  Future<void> _sendChatMessageWithFaq(String message) async {
    setState(() {
      _loading = true;
    });
    try {
      _generatedContent.add((image: null, text: message, fromUser: true));
      final faqJson = await getFaqData(message);
      const prompt = '''
คุณจะรับบทเป็น "พี่เจ้าหน้าที่" ของมหาวิทยาลัยเทคโนโลยีราชมงคลตะวันออกในการตอบคำถามให้กับน้องๆ 
ที่สนใจจะเข้าศึกษาต่อที่มหาวิทยาลัยเทคโนโลยีราชมงคลตะวันออก หรือ  RMUTTO คุณจะเรียกผู้ใช้ว่า 
"น้องนักศึกษา" หรือ "น้อง" เพื่อให้รู้สึกเป็นกันเอง และตอบคำถามอย่างตรงไปตรงมา หากคำถาม
ไม่เกี่ยวข้องกับการรับเข้าศึกษา หลักสูตรการศึกษา ค่าเล่าเรียน ทุนการศึกษา สิ่งอำนวยความสะดวก
ในมหาวิทยาลัย ชีวิตนักศึกษา และข้อมูลเกี่ยวกับคณาจารย์ของมหาวิทยาลัยเทคโนโลยีราชมงคลตะวันออก 
ให้แนะนำให้นักศึกษาติดต่อมหาวิทยาลัยที่เบอร์ 033-136-099 หรือ เว็บไซต์ https://www.rmutto.ac.th/
''';
      final fullPrompt = '''$prompt $faqJson ''';
      final tempModel = GenerativeModel(
        model: 'gemini-1.5-flash-latest',
        apiKey: widget.apiKey,
        systemInstruction: Content.system(fullPrompt),
      );

      final tempChat = tempModel.startChat();
      final response = await tempChat.sendMessage(Content.text(message));
      final text = response.text;

      _generatedContent.add((image: null, text: text, fromUser: false));
      _speakText(text!);

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
      _textFieldFocus.requestFocus();
    }
  }

  // Handle sending image along with prompt
  Future<void> _sendImagePrompt(String message) async {
    setState(() {
      _loading = true;
    });
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final bytes = await image.readAsBytes();
        final content = [
          Content.multi([
            TextPart(message),
            DataPart('image/jpeg', bytes),
          ])
        ];
        _generatedContent.add((image: Image.file(File(image.path)), text: message, fromUser: true));

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
      _textFieldFocus.requestFocus();
    }
  }

  // Start listening for speech input
  Future<String?> _listenForSpeech() async {
    final bool available = await _speechToText.initialize();
    if (!available) {
      print('Speech recognition not available.');
      return null;
    }

    String? recognizedText;
    _speechToText.listen(
      localeId: 'th-TH',
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

    await Future.delayed(const Duration(seconds: 5));
    _stopListenForSpeech();
    return recognizedText;
  }

  // Stop speech recognition
  Future<void> _stopListenForSpeech() async {
    await _speechToText.stop();
  }

  // Speak the given text using TTS
  Future<void> _speakText(String texts) async {
    await _tts.setLanguage('th-TH');
    await _tts.setSpeechRate(1);
    await _tts.speak(texts);
  }

  // Stop TTS speaking
  Future<void> _stopSpeakText() async {
    await _tts.stop();
  }

  // Scroll to bottom of chat list
  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback(
          (_) => _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 750),
        curve: Curves.easeOutCirc,
      ),
    );
  }

  // Display error message
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

  // Build the chat screen UI
  @override
  Widget build(BuildContext context) {
    final textFieldDecoration = InputDecoration(
      contentPadding: const EdgeInsets.all(15),
      hintText: 'Enter a prompt...',
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
            child: widget.apiKey.isNotEmpty
                ? _generatedContent.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'ถามคำถามเกี่ยวกับการรับสมัครเรียนของมหาวิทยาลัยราชมงคลตะวันออกได้ที่นี่',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
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
          // Input field and buttons
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
                    onSubmitted: _sendChatMessageWithFaq,
                  ),
                ),
                const SizedBox.square(dimension: 15),
                if (!_loading)
                  IconButton(
                    onPressed: () async {
                      _stopSpeakText();
                      final recognizedText = await _listenForSpeech();
                      if (recognizedText != null) {
                        _sendChatMessageWithFaq(recognizedText);
                      }
                    },
                    icon: const Icon(Icons.keyboard_voice),
                    color: const Color(0xFF5c9adb),
                  ),
                if (!_loading)
                  IconButton(
                    onPressed: () async {
                      _sendImagePrompt(_textController.text);
                    },
                    icon: Icon(
                      Icons.image,
                      color: const Color(0xFF5c9adb),
                    ),
                  ),
                if (!_loading)
                  IconButton(
                    onPressed: () {
                      _sendChatMessageWithFaq(_textController.text);
                    },
                    icon: Icon(
                      Icons.send,
                      color: const Color(0xFF5c9adb),
                    ),
                  )
                else
                  const CircularProgressIndicator(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}