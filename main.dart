import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

Future<Pokemon> fetchPokemon(int id) async {
  final uri = Uri.parse('https://pokeapi.co/api/v2/pokemon/$id');
  final res = await http.get(uri).timeout(const Duration(seconds: 10));

  if (res.statusCode == 200) {
    return Pokemon.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  } else {
    throw Exception('Failed to load pokemon (HTTP ${res.statusCode}) with id: $id');
  }
}

class Pokemon {
  final int id;
  final String name;
  final int height;
  final int weight;
  final String? sprite;

  const Pokemon({
    required this.id,
    required this.name,
    required this.height,
    required this.weight,
    this.sprite,
  });

  factory Pokemon.fromJson(Map<String, dynamic> j) => Pokemon(
        id: j['id'] as int,
        name: j['name'] as String,
        height: j['height'] as int,
        weight: j['weight'] as int,
        sprite: (j['sprites']?['front_default']) as String?,
      );
}

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const int minId = 1;
  static const int maxId = 1025;

  int _currentId = minId;
  late Future<Pokemon> _futurePokemon;
  bool _loading = false;

  // Handles the "Jump to ID" text field input
  final TextEditingController _jumpController = TextEditingController();

  // Stores favorite Pokémon IDs in memory
  final Set<int> _favorites = {};

  @override
  void initState() {
    super.initState();
    _futurePokemon = fetchPokemon(_currentId);
  }

  void _loadId(int id) {
    setState(() {
      _currentId = id.clamp(minId, maxId);
      _loading = true;
      _futurePokemon = fetchPokemon(_currentId).whenComplete(() {
        if (mounted) {
          setState(() {
            _loading = false;
          });
        }
      });
    });
  }

  void _next() => _loadId((_currentId + 1) > maxId ? minId : _currentId + 1);
  void _prev() => _loadId((_currentId - 1) < minId ? maxId : _currentId - 1);

  // Toggle favorites
  void _toggleFavorite(int id) {
    setState(() {
      if (_favorites.contains(id)) {
        _favorites.remove(id);
      } else {
        _favorites.add(id);
      }
    });
  }

  // Show a simple favorites list
  void _showFavorites(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Favorites', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (_favorites.isEmpty)
            const Text('No favorites yet.'),
          for (var id in _favorites)
            ListTile(
              leading: const Icon(Icons.star, color: Colors.amber),
              title: Text('Pokémon ID $id'),
              onTap: () {
                Navigator.pop(context);
                _loadId(id);
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pokémon Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.deepPurple),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Pokémon Demo'),
          actions: [
            IconButton(onPressed: _loading ? null : _prev, icon: const Icon(Icons.navigate_before)),
            IconButton(onPressed: _loading ? null : _next, icon: const Icon(Icons.navigate_next)),
            Builder(
              builder: (context) => IconButton(
                tooltip: 'Show Favorites',
                icon: const Icon(Icons.star),
                onPressed: () => _showFavorites(context),
              ),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Jump to ID Row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _jumpController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Jump to ID',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _loading
                        ? null
                        : () {
                            final id = int.tryParse(_jumpController.text);
                            if (id != null) _loadId(id);
                          },
                    child: const Text('Go'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // FutureBuilder
              Expanded(
                child: Center(
                  child: FutureBuilder<Pokemon>(
                    future: _futurePokemon,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting || _loading) {
                        return const CircularProgressIndicator();
                      }
                      if (snapshot.hasError) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Error: ${snapshot.error}', textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: () => _loadId(_currentId),
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                              ),
                            ],
                          ),
                        );
                      }

                      final item = snapshot.data!;
                      final isFav = _favorites.contains(item.id);

                      return Card(
                        margin: const EdgeInsets.all(16),
                        child: ListTile(
                          leading: item.sprite != null
                              ? Image.network(item.sprite!, width: 56, height: 56)
                              : CircleAvatar(child: Text('${item.id}')),
                          title: Text(item.name),
                          subtitle: Text('id: ${item.id}'),
                          trailing: IconButton(
                            icon: Icon(isFav ? Icons.star : Icons.star_border,
                                color: isFav ? Colors.amber : null),
                            onPressed: () => _toggleFavorite(item.id),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              FilledButton(onPressed: _loading ? null : _prev, child: const Text('Prev')),
              FilledButton(onPressed: _loading ? null : _next, child: const Text('Next')),
            ],
          ),
        ),
      ),
    );
  }
}
