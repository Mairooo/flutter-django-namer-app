import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MyAppState(),
      child: MaterialApp(
        title: 'Namer App',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlueAccent),
        ),
        home: MyHomePage(),
      ),
    );
  }
}

class MyAppState extends ChangeNotifier {
  var current = WordPair.random();
  var favorites = <WordPair>[];
  
  // Pour stocker le dernier message de notification
  String? lastNotification;
  
  // URL de base du backend Django
  static const String baseUrl = 'http://localhost:8000/api';

  MyAppState() {
    // Backend désactivé pour l'APK mobile
    // loadFavoritesFromBackend();
  }

  void getNext() {
    current = WordPair.random();
    notifyListeners();
  }

  // Retourne true si ajouté, false si retiré
  bool toggleFavorite() {
    bool wasAdded;
    if (favorites.contains(current)) {
      favorites.remove(current);
      // _removeFavoriteFromBackend(current.asLowerCase); // Backend désactivé
      lastNotification = '"${current.asLowerCase}" retiré des favoris';
      wasAdded = false;
    } else {
      favorites.add(current);
      // _addFavoriteToBackend(current.asLowerCase); // Backend désactivé
      lastNotification = '"${current.asLowerCase}" ajouté aux favoris!';
      wasAdded = true;
    }
    notifyListeners();
    return wasAdded;
  }

  // Charger les favoris depuis le backend
  Future<void> loadFavoritesFromBackend() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/favorites/'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        favorites.clear();
        for (var item in data) {
          final word = item['word'] as String;
          // Trouve la séparation entre les deux mots (cherche où le 2e mot commence)
          // Exemple: "catbase" -> "cat" + "base"
          int splitPoint = 1;
          for (int i = 1; i < word.length; i++) {
            if (word[i] == word[i].toLowerCase() && 
                (i + 1 < word.length && word[i + 1] == word[i + 1].toLowerCase())) {
              splitPoint = i;
            }
          }
          // Si on ne trouve pas de point de séparation logique, coupe au milieu
          if (splitPoint == 1 && word.length > 3) {
            splitPoint = word.length ~/ 2;
          }
          final first = word.substring(0, splitPoint);
          final second = word.substring(splitPoint);
          favorites.add(WordPair(first, second));
        }
        notifyListeners();
      }
    } catch (e) {
      print('Erreur lors du chargement des favoris: $e');
    }
  }

  // Ajouter un favori au backend (désactivé)
  // Future<void> _addFavoriteToBackend(String word) async {
  //   try {
  //     await http.post(
  //       Uri.parse('$baseUrl/favorites/'),
  //       headers: {'Content-Type': 'application/json'},
  //       body: jsonEncode({'word': word}),
  //     );
  //   } catch (e) {
  //     print('Erreur lors de l\'ajout du favori: $e');
  //   }
  // }

  // Supprimer un favori du backend (désactivé)
  // Future<void> _removeFavoriteFromBackend(String word) async {
  //   try {
  //     await http.delete(Uri.parse('$baseUrl/favorites/$word/'));
  //   } catch (e) {
  //     print('Erreur lors de la suppression du favori: $e');
  //   }
  // }
}


class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}
class _MyHomePageState extends State<MyHomePage> {
  var selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    Widget page;
    switch (selectedIndex) {
      case 0:
        page = GeneratorPage();
        break;
      case 1:
        page = FavoritesPage();
        break;
      default:
        throw UnimplementedError('no widget for $selectedIndex');
    }

    return LayoutBuilder(builder: (context, constraints) {
      return Scaffold(
        body: Row(
          children: [
            SafeArea(
              child: NavigationRail(
                extended: constraints.maxWidth >= 600,  // ← Here.
                destinations: [
                  NavigationRailDestination(
                    icon: Icon(Icons.home),
                    label: Text('Home'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.favorite),
                    label: Text('Favorites'),
                  ),
                ],
                selectedIndex: selectedIndex,
                onDestinationSelected: (value) {
                  setState(() {
                    selectedIndex = value;
                  });
                },
              ),
            ),
            Expanded(
              child: Container(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: page,
              ),
            ),
          ],
        ),
      );
    });
  }
}

class GeneratorPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    var pair = appState.current;

    IconData icon;
    if (appState.favorites.contains(pair)) {
      icon = Icons.favorite;
    } else {
      icon = Icons.favorite_border;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SwipeableCard(pair: pair),
          SizedBox(height: 20),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  // Toggle et récupère si c'était un ajout ou retrait
                  bool wasAdded = appState.toggleFavorite();
                  
                  // Affiche la notification SnackBar
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(appState.lastNotification ?? ''),
                      backgroundColor: wasAdded ? Colors.green : Colors.orange,
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: Icon(icon),
                label: Text('Like'),
              ),
              SizedBox(width: 10),
              ElevatedButton(
                onPressed: () {
                  appState.getNext();
                },
                child: Text('Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class BigCard extends StatelessWidget {
  const BigCard({
    super.key,
    required this.pair,
  });

  final WordPair pair;

  @override
  Widget build(BuildContext context) {
    
    final theme = Theme.of(context);
        final style = theme.textTheme.displayMedium!.copyWith(
      color: theme.colorScheme.onPrimary,
    );
      
    return Card(
      color: theme.colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          pair.asLowerCase,
          style: style,
          semanticsLabel: "${pair.first} ${pair.second}",
        ),
      ),
    );
  }
}

// Nouveau widget pour gérer le swipe
class SwipeableCard extends StatefulWidget {
  const SwipeableCard({
    super.key,
    required this.pair,
  });

  final WordPair pair;

  @override
  State<SwipeableCard> createState() => _SwipeableCardState();
}

class _SwipeableCardState extends State<SwipeableCard> with SingleTickerProviderStateMixin {
  double _dragOffset = 0.0;
  bool _isDragging = false;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    _animation = Tween<double>(begin: 0.0, end: 0.0).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
    });
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta.dx;
      // Limiter le déplacement maximum à 150px
      _dragOffset = _dragOffset.clamp(-150.0, 150.0);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    var appState = context.read<MyAppState>();
    
    // Seuil de swipe (en pixels) - réduit pour plus de sensibilité
    const double threshold = 80.0;
    
    if (_dragOffset > threshold) {
      // Swipe vers la droite = LIKE
      _animateCardOut(true, appState);
    } else if (_dragOffset < -threshold) {
      // Swipe vers la gauche = DISLIKE
      _animateCardOut(false, appState);
    } else {
      // Retour à la position initiale
      _animateCardBack();
    }
    
    setState(() {
      _isDragging = false;
    });
  }

  void _animateCardOut(bool isLike, MyAppState appState) {
    final targetOffset = isLike ? 400.0 : -400.0;
    
    _animation = Tween<double>(
      begin: _dragOffset,
      end: targetOffset,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ))..addListener(() {
        setState(() {
          _dragOffset = _animation.value;
        });
      });

    _animationController.forward(from: 0).then((_) {
      if (isLike) {
        // Ajouter aux favoris si ce n'est pas déjà fait
        if (!appState.favorites.contains(widget.pair)) {
          appState.toggleFavorite();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(appState.lastNotification ?? ''),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
      
      // Passer au mot suivant
      appState.getNext();
      
      // Réinitialiser la position
      setState(() {
        _dragOffset = 0.0;
      });
    });
  }

  void _animateCardBack() {
    _animation = Tween<double>(
      begin: _dragOffset,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ))..addListener(() {
        setState(() {
          _dragOffset = _animation.value;
        });
      });

    _animationController.forward(from: 0);
  }

  Future<void> _showDefinition(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.pair.asLowerCase),
        content: Text('Chargement...'),
      ),
    );

    try {
      // Essayer de récupérer les définitions des deux mots
      final word1 = widget.pair.first.toLowerCase();
      final word2 = widget.pair.second.toLowerCase();
      
      final response1 = await http.get(Uri.parse('https://api.dictionaryapi.dev/api/v2/entries/en/$word1'));
      final response2 = await http.get(Uri.parse('https://api.dictionaryapi.dev/api/v2/entries/en/$word2'));
      
      String definition = '';
      
      if (response1.statusCode == 200) {
        final data = jsonDecode(response1.body)[0];
        final meaning = data['meanings'][0]['definitions'][0]['definition'];
        definition += '${word1.toUpperCase()}: $meaning\n\n';
      }
      
      if (response2.statusCode == 200) {
        final data = jsonDecode(response2.body)[0];
        final meaning = data['meanings'][0]['definitions'][0]['definition'];
        definition += '${word2.toUpperCase()}: $meaning';
      }
      
      if (definition.isEmpty) {
        definition = 'Définition non trouvée';
      }
      
      Navigator.of(context).pop(); // Fermer le loading
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(widget.pair.asLowerCase),
          content: SingleChildScrollView(
            child: Text(definition),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Fermer'),
            ),
          ],
        ),
      );
    } catch (e) {
      Navigator.of(context).pop(); // Fermer le loading
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(widget.pair.asLowerCase),
          content: Text('Erreur lors de la récupération de la définition'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Fermer'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.displayMedium!.copyWith(
      color: theme.colorScheme.onPrimary,
    );

    return GestureDetector(
      onHorizontalDragStart: _onHorizontalDragStart,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      onTap: () => _showDefinition(context),
      child: Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: Transform.rotate(
              angle: _dragOffset / 1000,
              child: Card(
                elevation: _isDragging ? 8.0 : 4.0,
                color: theme.colorScheme.primary,
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Text(
                    widget.pair.asLowerCase,
                    style: style,
                    semanticsLabel: "${widget.pair.first} ${widget.pair.second}",
                  ),
                ),
              ),
            ),
          ),
    );
  }
}

class FavoritesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();

    if (appState.favorites.isEmpty) {
      return Center(
        child: Text('No favorites yet.'),
      );
    }

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text('You have '
              '${appState.favorites.length} favorites:'),
        ),
        for (var pair in appState.favorites)
          ListTile(
            leading: Icon(Icons.favorite),
            title: Text(pair.asLowerCase),
          ),
      ],
    );
  }
}

