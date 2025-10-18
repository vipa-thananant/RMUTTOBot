import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../ConnectAPI/api_keys.dart';
import '../Widget_UI/MassageWidget.dart';

class Homescreen extends StatelessWidget {
  const Homescreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("RMUTTOBot (TAG System)"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: const ChatWidget(apiKey: GeminiConfig.apiKey),
    );
  }
}

// --- FUNCTION CALLING TOOL DEFINITION ---
// This defines the 'get_tuition_fee' function for the Gemini model.
var getTuitionFeeTool = Tool(
  functionDeclarations: [
    FunctionDeclaration(
      'get_tuition_fee',
      'Gets the tuition fee for a specific major.',
      Schema(
        SchemaType.object,
        properties: {
          'major': Schema(
            SchemaType.string,
            description: 'The name of the major, e.g., "Computer Engineering"',
          ),
        },
        requiredProperties: ['major'],
      ),
    ),
  ],
);


// --- CHAT WIDGET ---
class ChatWidget extends StatefulWidget {
  final String apiKey;
  const ChatWidget({required this.apiKey, super.key});

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> {
  late final GenerativeModel _model;
  late final ChatSession _chat;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFieldFocus = FocusNode();
  bool _loading = false;
  List<Map<String, dynamic>> _allFaqList = [];
  final List<({String? text, bool fromUser})> _generatedContent = [];

  @override
  void initState() {
    super.initState();

    // Define the system's persona and instructions.
    const systemPrompt = '''
คุณจะรับบทเป็น "พี่เจ้าหน้าที่" ของมหาวิทยาลัยเทคโนโลยีราชมงคลตะวันออกในการตอบคำถามให้กับน้องๆ 
ที่สนใจจะเข้าศึกษาต่อที่มหาวิทยาลัยเทคโนโลยีราชมงคลตะวันออก หรือ  RMUTTO คุณจะเรียกผู้ใช้ว่า 
"น้องนักศึกษา" หรือ "น้อง" เพื่อให้รู้สึกเป็นกันเอง และตอบคำถามอย่างตรงไปตรงมา หากคำถาม
ไม่เกี่ยวข้องกับการรับเข้าศึกษา หลักสูตรการศึกษา ค่าเล่าเรียน ทุนการศึกษา สิ่งอำนวยความสะดวก
ในมหาวิทยาลัย ชีวิตนักศึกษา และข้อมูลเกี่ยวกับคณาจารย์ของมหาวิทยาลัยเทคโนโลยีราชมงคลตะวันออก 
ให้แนะนำให้นักศึกษาติดต่อมหาวิทยาลัยที่เบอร์ 033-136-099 หรือ เว็บไซต์ https://www.rmutto.ac.th/
''';

    // Initialize the model with the tool and system prompt.
    _model = GenerativeModel(
      model: 'gemini-1.5-flash-latest',
      apiKey: widget.apiKey,
      tools: [getTuitionFeeTool], // <-- Pass the tool to the model
      systemInstruction: Content.system(systemPrompt),
    );
    _chat = _model.startChat();
  }

  // --- MOCK DATABASE FUNCTION ---
  // This simulates your app's backend querying a live database.
  Future<Map<String, dynamic>> getTuitionFeeFromDatabase(String major) async {
    print(" Executing pre-defined query for major: $major");
    // In a real app, replace this with a call to your live university financial database.
    final mockDatabase = {
      'Computer Engineering': 30000,
      'Agricultural Engineering': 25000,
      'Marketing': 22000,
      'วิศวกรรมคอมพิวเตอร์': 30000, // Handle Thai names
    };

    final fee = mockDatabase[major];
    if (fee != null) {
      return {'tuition_fee': fee};
    } else {
      return {'error': 'Tuition fee for $major not found.'};
    }
  }

  // --- STATIC QA KNOWLEDGE BASE (RAG) ---
  Future<void> loadFaqDataOnce() async {
    // In a real app, you might fetch this from Firebase Firestore.
    _allFaqList = [
      {
        "คำถาม": "สาขาวิศวกรรมคอมพิวเตอร์เรียนเกี่ยวกับอะไร",
        "คำตอบ": "สาขาวิศวกรรมคอมพิวเตอร์มุ่งเน้นการออกแบบและพัฒนาทั้งฮาร์ดแวร์และซอฟต์แวร์คอมพิวเตอร์ รวมถึงระบบเครือข่ายและความปลอดภัย",
      },
      {
        "คำถาม": "มหาวิทยาลัยมีทั้งหมดกี่คณะ",
        "คำตอบ": "มี 7 คณะ ได้แก่ คณะเกษตรศาสตร์และทรัพยากรธรรมชาติ, คณะบริหารธุรกิจและเทคโนโลยีสารสนเทศ, คณะวิศวกรรมศาสตร์และเทคโนโลยี, และอื่นๆ",
      },
      // ... add more static QA pairs here
    ];
  }

  // --- MOCK SEMANTIC SEARCH ---
  // This simulates your semantic search backend.
  Future<List<String>> getTopFaqMatches(String query) async {
    if (_allFaqList.isEmpty) {
      await loadFaqDataOnce();
    }
    // This is a simplified mock. In your real app, this would be an HTTP call
    // to your semantic search server (getTopMatches).
    List<String> matches = [];
    for (var faq in _allFaqList) {
      if ((faq['คำถาม'] as String).contains('คอมพิวเตอร์')) {
        matches.add(jsonEncode(faq));
      }
    }
    return matches;
  }

  // --- CORE CHAT LOGIC ---
  Future<void> _sendChatMessage(String message) async {
    if (message.isEmpty) return;
    setState(() {
      _loading = true;
      _generatedContent.add((text: message, fromUser: true));
    });

    try {
      // 1. Retrieve general context from the static QA knowledge base.
      final faqMatches = await getTopFaqMatches(message);
      final faqContext = faqMatches.join('\n');

      // 2. Consolidate context for the first LLM call.
      final content = Content.multi([
        TextPart('Use this context from the QA database if relevant: $faqContext'),
        TextPart('Now, answer this user query: $message'),
      ]);

      // 3. Send the message to the LLM.
      var response = await _chat.sendMessage(content);

      // 4. Check if the LLM wants to call our function.
      final functionCall = response.candidates?.first.content.parts
          .whereType<FunctionCall>()
          .firstOrNull;

      if (functionCall != null) {
        print(' LLM triggered function call: ${functionCall.name}');
        if (functionCall.name == 'get_tuition_fee') {
          final major = functionCall.args['major'] as String?;
          if (major != null) {
            // 5. Execute the pre-defined database query.
            final apiResponse = await getTuitionFeeFromDatabase(major);

            // 6. Send the database result back to the LLM.
            response = await _chat.sendMessage(
              Content.functionResponse(functionCall.name, apiResponse),
            );
          }
        }
      }

      // 7. The final response is synthesized by the LLM. Update the UI.
      final finalText = response.text;
      if (finalText != null) {
        setState(() {
          _generatedContent.add((text: finalText, fromUser: false));
        });
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() {
        _loading = false;
        _scrollDown();
      });
      _textController.clear();
      _textFieldFocus.requestFocus();
    }
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback(
          (_) => _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 750),
        curve: Curves.easeOutCirc,
      ),
    );
  }

  void _showError(String message) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Something went wrong'),
          content: SingleChildScrollView(child: SelectableText(message)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Expanded(
            child: _generatedContent.isNotEmpty
                ? ListView.builder(
              controller: _scrollController,
              itemCount: _generatedContent.length,
              itemBuilder: (context, idx) {
                final content = _generatedContent[idx];
                return MessageWidget(
                  text: content.text ?? '',
                  isFromUser: content.fromUser,
                );
              },
            )
                : const Center(child: Text('Ask me about admissions at RMUTTO!')),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    focusNode: _textFieldFocus,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.all(15),
                      hintText: 'Enter a prompt...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onSubmitted: _sendChatMessage,
                  ),
                ),
                const SizedBox.square(dimension: 15),
                if (!_loading)
                  IconButton(
                    onPressed: () => _sendChatMessage(_textController.text),
                    icon: Icon(Icons.send, color: Theme.of(context).primaryColor),
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

