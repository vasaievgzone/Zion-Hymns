import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyCco5kzz8RTXzO9Eak3v1HMa_QEo6M5OFo",
        authDomain: "zion-hymns-cc4a9.firebaseapp.com",
        projectId: "zion-hymns-cc4a9",
        storageBucket: "zion-hymns-cc4a9.firebasestorage.app",
        messagingSenderId: "726415460666",
        appId: "1:726415460666:web:8a3a27f1dae89f359be803",
        measurementId: "G-707963S3BZ",
      ),
    );
  } else {
    await Firebase.initializeApp();
  }
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;
  MaterialColor _seedColor = Colors.deepPurple;

  final Map<String, MaterialColor> _colorOptions = {
    'Purple': Colors.deepPurple,
    'Red': Colors.red,
    'Blue': Colors.blue,
    'Green': Colors.green,
    'Orange': Colors.orange,
    'Teal': Colors.teal,
  };

  @override
  void initState() {
    super.initState();
    _loadThemePrefs();
  }

  void _loadThemePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _themeMode = prefs.getBool('darkMode') == true? ThemeMode.dark : ThemeMode.light;
      String colorName = prefs.getString('seedColor')?? 'Purple';
      _seedColor = _colorOptions[colorName]?? Colors.deepPurple;
    });
  }

  void toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _themeMode = _themeMode == ThemeMode.light? ThemeMode.dark : ThemeMode.light;
      prefs.setBool('darkMode', _themeMode == ThemeMode.dark);
    });
  }

  void changeSeedColor(String colorName) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _seedColor = _colorOptions[colorName]?? Colors.deepPurple;
      prefs.setString('seedColor', colorName);
    });
  }

  void showColorPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choose Theme Color'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _colorOptions.keys.map((name) {
            return ListTile(
              leading: CircleAvatar(backgroundColor: _colorOptions[name]),
              title: Text(name),
              onTap: () {
                changeSeedColor(name);
                Navigator.pop(ctx);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Zion Hymns',
      scrollBehavior: const MaterialScrollBehavior().copyWith(scrollbars: false),
      theme: ThemeData.light(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: _seedColor, brightness: Brightness.light),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 16, height: 1.6, fontFamily: 'Roboto', color: Colors.black87),
          titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Roboto', color: Colors.black),
        ),
      ),
      darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: _seedColor, brightness: Brightness.dark),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 16, height: 1.6, fontFamily: 'Roboto', color: Colors.white),
          titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Roboto', color: Colors.white),
        ),
      ),
      themeMode: _themeMode,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData) {
            return HymnListScreen(
              toggleTheme: toggleTheme,
              themeMode: _themeMode,
              showColorPicker: () => showColorPicker(context),
            );
          }
          return const LoginScreen();
        },
      ),
    );
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  Future<void> signInWithGoogle(BuildContext context) async {
    try {
      if (kIsWeb) {
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        await FirebaseAuth.instance.signInWithPopup(googleProvider);
      } else {
        final GoogleSignIn googleSignIn = GoogleSignIn();
        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
        if (googleUser == null) return;
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
  accessToken: googleAuth.accessToken,
  idToken: googleAuth.idToken,
);
        await FirebaseAuth.instance.signInWithCredential(credential);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => signInWithGoogle(context),
          child: const Text('Sign in with Google'),
        ),
      ),
    );
  }
}

class HymnListScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  final ThemeMode themeMode;
  final VoidCallback showColorPicker;
  const HymnListScreen({super.key, required this.toggleTheme, required this.themeMode, required this.showColorPicker});
  @override
  State<HymnListScreen> createState() => _HymnListScreenState();
}

class _HymnListScreenState extends State<HymnListScreen> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, int> pageNumbers = {};
  final Set<String> _selectedPages = {};
  List<QueryDocumentSnapshot> _allHymns = [];

  String? _selectedYear;
  String? _selectedMode;
  String? _selectedDedicatedTo;
  String? _selectedName;

  Widget _buildRoleIcon(String? role) {
    if (role == "super_admin") {
      return const Padding(
        padding: EdgeInsets.only(left: 6),
        child: Icon(Icons.workspace_premium, color: Colors.amber, size: 18),
      );
    } else if (role == "admin") {
      return const Padding(
        padding: EdgeInsets.only(left: 6),
        child: Icon(Icons.edit, color: Colors.blue, size: 18),
      );
    }
    return const SizedBox.shrink();
  }

  void _showFrozenHymns() {
  if (_selectedPages.isEmpty) return;

  List<Map<String, dynamic>> frozenHymns = [];

  for (String hymnId in _selectedPages) {
    final doc = _allHymns.firstWhere(
      (d) => d.id == hymnId,
    );

    final hymn = Map<String, dynamic>.from(
      doc.data() as Map<String, dynamic>,
    );

    hymn['id'] = doc.id;
    hymn['pageNum'] = pageNumbers[doc.id];

    frozenHymns.add(hymn);
  }

      showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              AppBar(
                title: Text('Frozen Hymns - ${_selectedPages.length} selected'),
                automaticallyImplyLeading: false,
                backgroundColor: Colors.black87,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() => _selectedPages.clear());
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: frozenHymns.length,
                  itemBuilder: (context, idx) {
                    final hymn = frozenHymns[idx];
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                border: Border.all(color: Colors.black, width: 2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                hymn['title']?? '',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text('${hymn['key']?? 'N/A'} • ${hymn['year']?? 'N/A'} • ${hymn['mode']?? ''}',
                                style: TextStyle(color: Colors.grey.shade600)),
                            const Divider(height: 20),
                            Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Text(hymn['lyrics']?? '',
                                  style: const TextStyle(fontSize: 16, height: 1.6, fontFamily: 'Roboto')),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Zion Hymns'),
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(user?.uid).get(),
              builder: (context, snap) {
                if (!snap.hasData ||!snap.data!.exists) return const SizedBox.shrink();
                final role = snap.data!.get('role') as String?;
                return _buildRoleIcon(role);
              },
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_selectedYear!= null || _selectedMode!= null || _selectedDedicatedTo!= null || _selectedName!= null)
            IconButton(
              icon: const Icon(Icons.restart_alt, color: Colors.orange),
              tooltip: 'Reset Filters',
              onPressed: () => setState(() {
                _selectedYear = null;
                _selectedMode = null;
                _selectedDedicatedTo = null;
                _selectedName = null;
              }),
            ),
          if (_selectedPages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text('${_selectedPages.length} Frozen',
                    style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.palette),
            onPressed: widget.showColorPicker,
            tooltip: 'Change Theme Color',
          ),
          IconButton(
            icon: Icon(widget.themeMode == ThemeMode.light? Icons.dark_mode : Icons.light_mode),
            onPressed: widget.toggleTheme,
            tooltip: 'Toggle Dark Mode',
          ),
          PopupMenuButton(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CircleAvatar(
                backgroundImage: user?.photoURL!= null? NetworkImage(user!.photoURL!) : null,
                child: user?.photoURL == null? Text(user?.displayName?.substring(0, 1)?? 'U') : null,
              ),
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                child: ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Logout'),
                onTap: () async {
  Navigator.pop(context);
  await GoogleSignIn().signOut();
  await FirebaseAuth.instance.signOut();
},
                ),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('hymns').orderBy('title').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
                                                              if (!snapshot.hasData) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }

                                _allHymns = snapshot.data!.docs;

                          _allHymns.sort((a, b) {
                            final titleA =
                                ((a.data() as Map<String, dynamic>)['title'] ?? '')
                                    .toString()
                                    .toLowerCase();

                            final titleB =
                                ((b.data() as Map<String, dynamic>)['title'] ?? '')
                                    .toString()
                                    .toLowerCase();

                            return titleA.compareTo(titleB);
                          });
                            pageNumbers.clear();

                  for (int i = 0; i < _allHymns.length; i++) {
                    pageNumbers[_allHymns[i].id] = i + 1;
                  }

          var filtered = _allHymns.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            bool matches = true;
            if (_selectedName!= null && data['title']!= _selectedName) matches = false;
            if (_selectedYear!= null && data['year']?.toString()!= _selectedYear) matches = false;
            if (_selectedMode!= null && data['mode']!= _selectedMode) matches = false;
            if (_selectedDedicatedTo!= null && data['dedicated']!= _selectedDedicatedTo) matches = false;
            return matches;
          }).toList();

          final docs = filtered;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        TextEditingController titleController = TextEditingController();
                        TextEditingController lyricsController = TextEditingController();
                        TextEditingController keyController = TextEditingController();
                        TextEditingController yearController = TextEditingController();
                        TextEditingController chordController = TextEditingController();
                        TextEditingController dedicatedController = TextEditingController();
                        List<String> selectedCategories = [];
                        String detectedMode = 'Major';
                        final categoriesSnapshot = await FirebaseFirestore.instance
                          .collection('hymns')
                          .orderBy('title')
                          .get();
                        final categories = categoriesSnapshot.docs
                          .map((doc) => doc['title'].toString())
                          .toSet()
                          .toList();
                        final keys = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
                        showDialog(
                          context: context,
                          builder: (ctx) => StatefulBuilder(
                            builder: (context, setState) {
                              void detectMode(String chord) {
                                if (chord.isEmpty) return;
                                setState(() {
                                  detectedMode = chord.endsWith('m') || chord.endsWith('min')? 'Minor' : 'Major';
                                });
                              }
                              return AlertDialog(
                                title: const Text('Add New Hymn'),
                                content: SizedBox(
                                  width: 400,
                                  child: SingleChildScrollView(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TextField(
                                          controller: titleController,
                                          decoration: const InputDecoration(labelText: 'Title *'),
                                        ),
                                        TextField(
                                          controller: lyricsController,
                                          decoration: const InputDecoration(labelText: 'Lyrics *'),
                                          maxLines: 8,
                                          style: const TextStyle(fontFamily: 'Roboto', fontSize: 16, height: 1.6),
                                        ),
                                        Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Related Songs',
                                                  style: TextStyle(fontWeight: FontWeight.bold),
                                                ),

                                                const SizedBox(height: 8),

                                                Wrap(
                                                  spacing: 6,
                                                  children: selectedCategories.map((song) {
                                                    return Chip(
                                                      label: Text(song),
                                                      deleteIcon: const Icon(Icons.close),
                                                      onDeleted: () {
                                                        setState(() {
                                                          selectedCategories.remove(song);
                                                        });
                                                      },
                                                    );
                                                  }).toList(),
                                                ),

                                                DropdownButtonFormField<String>(
                                                  decoration: const InputDecoration(
                                                    labelText: 'Add Related Song',
                                                  ),
                                                  items: categories.map((cat) {
                                                    return DropdownMenuItem(
                                                      value: cat,
                                                      child: Text(cat),
                                                    );
                                                  }).toList(),
                                                  onChanged: (val) {
                                                    if (val == null) return;

                                                    setState(() {
                                                      if (!selectedCategories.contains(val)) {
                                                        selectedCategories.add(val);
                                                      }
                                                    });
                                                  },
                                                ),
                                              ],
                                            ),
                                                                                DropdownButtonFormField<String>(
                                          value: keyController.text.isEmpty? null : keyController.text,
                                          decoration: const InputDecoration(labelText: 'Key'),
                                          items: keys.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
                                          onChanged: (val) => keyController.text = val?? '',
                                        ),
                                        TextField(
                                          controller: chordController,
                                          decoration: InputDecoration(
                                            labelText: 'First Chord',
                                            suffixText: detectedMode,
                                          ),
                                          onChanged: detectMode,
                                        ),
                                        TextField(
                                          controller: yearController,
                                          decoration: const InputDecoration(labelText: 'Year'),
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                        ),
                                        Autocomplete<String>(
                           optionsBuilder: (textEditingValue) async {
                          if (textEditingValue.text.isEmpty) {
                            return const Iterable<String>.empty();
                          }

                          final snap = await FirebaseFirestore.instance
                              .collection('hymns')
                              .get();

                                    final values = snap.docs
                                        .map((d) => d['dedicated']?.toString() ?? '')
                                        .where((v) =>
                                            v.isNotEmpty &&
                                            v.toLowerCase().contains(
                                              textEditingValue.text.toLowerCase(),
                                            ))
                                        .toSet();

                                    return values;
                                  },
                                  fieldViewBuilder: (
                                    context,
                                    controller,
                                    focusNode,
                                    onFieldSubmitted,
                                  ) {
                                    dedicatedController = controller;

                                    return TextField(
                                      controller: controller,
                                      focusNode: focusNode,
                                      decoration: const InputDecoration(
                                        labelText: 'Dedicated To',
                                      ),
                                    );
                                  },
                                 ),
                                      ],
                                    ),
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      titleController.clear();
                                      lyricsController.clear();
                                      keyController.clear();
                                      yearController.clear();
                                      chordController.clear();
                                      dedicatedController.clear();
                                      setState(() {
                                        selectedCategories.clear();
                                        detectedMode = 'Major';
                                      });
                                    },
                                    child: const Text('Reset'),
                                  ),
                                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                  ElevatedButton(
                                    onPressed: () async {
                                      if (titleController.text.trim().isEmpty ||
    lyricsController.text.trim().isEmpty) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Title & Lyrics are mandatory'),
      backgroundColor: Colors.red,
    ),
  );
  return;
}

final existingSongs = await FirebaseFirestore.instance
    .collection('hymns')
    .where(
      'title',
      isEqualTo: titleController.text.trim(),
    )
    .get();

if (existingSongs.docs.isNotEmpty) {
  bool? continueSave = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Song already exists'),
      content: Text(
        '"${titleController.text.trim()}" already exists.\n\nDo you want to continue?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
                                          ElevatedButton(
                                     onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Continue'),
                                         ),
                                              ],
                                            ),
                                          );
                                      if (continueSave != true) {
                                     return;
                              }
                                            }

                                        await FirebaseFirestore.instance.collection('hymns').add({
                                        'title': titleController.text.trim(),
                                        'lyrics': lyricsController.text.trim(),
                                        'relatedSongs': selectedCategories,
                                        'key': keyController.text.trim(),
                                        'mode': detectedMode,
                                        'year': int.tryParse(yearController.text)?? 0,
                                        'dedicated': dedicatedController.text.trim(),
                                        'chords': chordController.text.trim().isEmpty? [] : [chordController.text.trim()],
                                        'createdAt': FieldValue.serverTimestamp(),
                                      });
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Hymn added! Mode: $detectedMode'), backgroundColor: Colors.green),
                                      );
                                    },
                                    child: const Text('Add'),
                                  ),
                                ],
                              );
                            },
                          ),
                        );
                      },
                      child: const Text("Add Song"),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () {},
                      child: const Text("Search"),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: docs.isEmpty
                  ? Center(
                        child: Text(
                          'No hymns yet.\n\nAdd from mobile 📱',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                         child: SingleChildScrollView(
                         controller: _scrollController,
                         physics: const BouncingScrollPhysics(),
                         scrollDirection: Axis.vertical,
                          child: Theme(
                          data: Theme.of(context).copyWith(
                            dividerTheme: const DividerThemeData(color: Colors.black, thickness: 2),
                          ),
                          child: DataTable(
                            border: TableBorder.all(width: 2, color: Colors.black87),
                            columnSpacing: 20,
                            columns: [
                              const DataColumn(label: Text('Serial No', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                              DataColumn(
                                label: Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Text('Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  PopupMenuButton<String>(
                                    icon: Icon(Icons.filter_list, size: 18, color: _selectedName!= null? Colors.orange : Colors.grey),
                                    onSelected: (val) => setState(() => _selectedName = val == 'All'? null : val),
                                    itemBuilder: (ctx) => ['All',..._allHymns.map((h) => (h.data() as Map)['title']?.toString()).where((t) => t!= null).toSet()]
                                      .map((t) => PopupMenuItem(value: t, child: Text(t!))).toList(),
                                  ),
                                ]),
                              ),
                              DataColumn(
                                label: Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Text('Year', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  PopupMenuButton<String>(
                                    icon: Icon(Icons.filter_list, size: 18, color: _selectedYear!= null? Colors.orange : Colors.grey),
                                    onSelected: (val) => setState(() => _selectedYear = val == 'All'? null : val),
                                    itemBuilder: (ctx) => ['All',..._allHymns.map((h) => (h.data() as Map)['year']?.toString()).where((y) => y!= null && y!= '0').toSet()]
                                      .map((y) => PopupMenuItem(value: y, child: Text(y!))).toList(),
                                  ),
                                ]),
                              ),
                              DataColumn(
                                label: Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Text('Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  PopupMenuButton<String>(
                                    icon: Icon(Icons.filter_list, size: 18, color: _selectedMode!= null? Colors.orange : Colors.grey),
                                    onSelected: (val) => setState(() => _selectedMode = val == 'All'? null : val),
                                    itemBuilder: (ctx) => ['All', 'Major', 'Minor'].map((m) => PopupMenuItem(value: m, child: Text(m))).toList(),
                                  ),
                                ]),
                              ),
                              DataColumn(
                                label: Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Text('Dedicated', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  PopupMenuButton<String>(
                                    icon: Icon(Icons.filter_list, size: 18, color: _selectedDedicatedTo!= null? Colors.orange : Colors.grey),
                                    onSelected: (val) => setState(() => _selectedDedicatedTo = val == 'All'? null : val),
                                    itemBuilder: (ctx) => ['All',..._allHymns.map((h) => (h.data() as Map)['dedicated']?.toString()).where((d) => d!= null && d.isNotEmpty).toSet()]
                                      .map((d) => PopupMenuItem(value: d, child: Text(d!))).toList(),
                                  ),
                                ]),
                              ),
                              const DataColumn(label: Text('Page', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                            ],
                            rows: docs.asMap().entries.map((entry) {
                              int index = entry.key;
                              var doc = entry.value;
                              final hymn = doc.data() as Map<String, dynamic>;
                              hymn['id'] = doc.id;
                              bool isSelected = _selectedPages.contains(doc.id);
                              return DataRow(
                                color: MaterialStateProperty.all(isSelected? Colors.orange.shade100 : null),
                                cells: [
                                  DataCell(Text('${pageNumbers[doc.id]}')),
                                    DataCell(Text(hymn['title']?.toString() ?? 'N/A')),
                                    DataCell(Text(hymn['year']?.toString()?? 'N/A')),
                                  DataCell(Text(hymn['mode']?.toString()?? 'N/A')),
                                  DataCell(Text(hymn['dedicated']?.toString()?? 'N/A')),
                                  DataCell(
                                    InkWell(
                                      onTap: () => Navigator.push(
                                        context,
                                    MaterialPageRoute(builder: (_) =>HymnDetailScreen(
                                      hymn: hymn,
                                      allDocs: docs,
                                      currentIndex: index,
                                      pageNumbers: pageNumbers,
                                    ))
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: isSelected? Colors.orange : Colors.deepPurple,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text('${pageNumbers[doc.id] ?? (index + 1)}',
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ), // DataTable
                        ),   // Theme
                      ),     // Vertical SingleChildScrollView
                    ),       // Horizontal SingleChildScrollView
                  ),         // Expanded
                ],
          );
        },
      ),
      floatingActionButton: _selectedPages.isNotEmpty
        ? FloatingActionButton.extended(
              backgroundColor: Colors.orange,
              onPressed: _showFrozenHymns,
              icon: const Icon(Icons.push_pin),
              label: Text('Freeze ${_selectedPages.length}'),
            )
          : null,
    );
  }
}


  class HymnDetailScreen extends StatefulWidget {
  final Map<String, dynamic> hymn;
  final List<QueryDocumentSnapshot> allDocs;
  final int currentIndex;
  final Map<String, int> pageNumbers;
  const HymnDetailScreen({
    super.key,
    required this.hymn,
    required this.allDocs,
    required this.currentIndex,
    required this.pageNumbers,
  });

  @override
  State<HymnDetailScreen> createState() => _HymnDetailScreenState();
}

class _HymnDetailScreenState extends State<HymnDetailScreen> {
  late PageController _pageController;
  late int currentIndex;
  
void _shareHymn(Map<String, dynamic> hymn) {
  final title = hymn['title'] ?? 'Song';
  final lyrics = hymn['lyrics'] ?? '';
  final text = '🎵 $title\n$lyrics\nShared from Zion Hymns App';
  Share.share(text);
}
  @override
  void initState() {
    super.initState();
    currentIndex = widget.currentIndex;
    _pageController = PageController(initialPage: currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _editField(String field, Map<String, dynamic> hymn, String id) async {
    TextEditingController controller = TextEditingController(text: hymn[field]?.toString()?? '');
    String? selectedValue;
    if (field == 'key') selectedValue = hymn['key'];
    else if (field == 'category') selectedValue = '';

    final keys = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    final categoriesSnapshot = await FirebaseFirestore.instance.collection('hymns').orderBy('title').get();
    final categories = categoriesSnapshot.docs.map((doc) => doc['title'].toString()).toSet().toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit $field'),
        content: field == 'key'
         ? DropdownButtonFormField<String>(
              value: selectedValue,
              items: keys.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
              onChanged: (val) => selectedValue = val,
            )
          : field == 'category'
         ? DropdownButtonFormField<String>(
              value: selectedValue,
              items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (val) => selectedValue = val,
              hint: const Text('Select hymn'),
            )
          : TextField(controller: controller, maxLines: field == 'lyrics'? 8 : 1),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              String newValue = field == 'key' || field == 'category'? selectedValue?? '' : controller.text;
              await FirebaseFirestore.instance.collection('hymns').doc(id).update({field: newValue});
              setState(() {});
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showRelatedHymn(String title) async {
  final snap = await FirebaseFirestore.instance
      .collection('hymns')
      .where('title', isEqualTo: title)
      .get();

  if (!mounted) return;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return ListView(
        children: snap.docs.map((doc) {
          final song = doc.data();

          return ListTile(
            title: Text(song['title'] ?? ''),
            subtitle: Text(
              (song['lyrics'] ?? '').toString().split('\n').take(2).join('\n'),
              maxLines: 2,
            ),
            trailing: const Icon(Icons.arrow_forward),
            onTap: () {
              Navigator.pop(context);

              int newIndex = widget.allDocs.indexWhere(
                (d) => d.id == doc.id,
              );

              if (newIndex != -1) {
                _pageController.animateToPage(
                  newIndex,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }
            },
          );
        }).toList(),
      );
    },
  );
}

  List<String> _toList(dynamic data) {
    if (data == null) return [];
    if (data is List) return List<String>.from(data.map((e) => e.toString()));
    if (data is String) return data.split(' ').where((s) => s.trim().isNotEmpty).toList();
    return [];
  }

  Widget _buildInfoChip(String label, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$label: ', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(width: 4),
            const Icon(Icons.edit, size: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildHymnPage(Map<String, dynamic> hymn, String id) {
    List<String> chords = _toList(hymn['chords']);
    List<String> related = _toList(hymn['relatedSongs']);

    return GestureDetector(
  onVerticalDragEnd: (details) {
    if (details.primaryVelocity == null) return;

    // Swipe up → next page
    if (details.primaryVelocity! < 0 &&
        currentIndex < widget.allDocs.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }

    // Swipe down → previous page
    if (details.primaryVelocity! > 0 &&
        currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  },
  child: SingleChildScrollView(
    physics: const BouncingScrollPhysics(),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildInfoChip('Key', hymn['key']?? 'N/A', () => _editField('key', hymn, id)),
                  const SizedBox(width: 8),
                  _buildInfoChip('Mode', hymn['mode']?? 'N/A', () {}),
                  const SizedBox(width: 8),
                  _buildInfoChip('Year', hymn['year']?.toString()?? 'N/A', () => _editField('year', hymn, id)),
                  const SizedBox(width: 8),
                  _buildInfoChip('Dedicated', hymn['dedicated']?.toString()?? 'N/A', () => _editField('dedicated', hymn, id)),
                  const SizedBox(width: 8),
                  _buildInfoChip('Related',related.isEmpty ? 'None' : '${related.length} songs',() {},),
                ]
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black87,
                border: Border.all(color: Colors.black, width: 3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                hymn['title']?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Lyrics:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                hymn['lyrics']?? '',
                style: const TextStyle(fontSize: 16, height: 1.6, fontFamily: 'Roboto'),
              ),
            ),
            if (chords.isNotEmpty)...[
              const SizedBox(height: 16),
              const Text('Chords:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Wrap(spacing: 8, children: chords.map((c) => Chip(label: Text(c))).toList()),
            ],
            if (related.isNotEmpty)...[
              const SizedBox(height: 16),
              const Text('Related Hymns:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ...related.map((r) => ListTile(
                title: Text(r),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () => _showRelatedHymn(r),
              )),
            ],
          ],
        ),
      ),
  ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
     appBar: AppBar(
  leading: IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => Navigator.pop(context),
  ),
                                                    title: Text(
                        'Page ${widget.pageNumbers[widget.allDocs[currentIndex].id]}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade300,
                        ),
                      ),
  backgroundColor: Theme.of(context).colorScheme.inversePrimary,
  actions: [
  IconButton(
    icon: const Icon(Icons.share),
    onPressed: () {
      final doc = widget.allDocs[currentIndex];
      final hymn = doc.data() as Map<String, dynamic>;
      _shareHymn(hymn);
    },
  ),
],
),
            body: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) => setState(() => currentIndex = index),
        itemCount: widget.allDocs.length,
        itemBuilder: (context, index) {
                          final doc = widget.allDocs[index];
                          final hymn = Map<String, dynamic>.from(doc.data() as Map);

                          hymn['id'] = doc.id;
                          hymn['pageNumber'] = index + 1;
                          return _buildHymnPage(hymn, doc.id);
        },
     ),
    );
  }
  }