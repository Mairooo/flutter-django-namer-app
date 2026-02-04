import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
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
  WordPair? lastRemoved; // Pour le bouton retour

  // Pour stocker le dernier message de notification
  String? lastNotification;

  MyAppState() {
    // Charger les favoris locaux au démarrage
    _loadLocalFavorites();
  }

  // Charger les favoris depuis le stockage local
  Future<void> _loadLocalFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final savedFavorites = prefs.getStringList('favorites') ?? [];
    favorites = savedFavorites.map((word) {
      // Séparer le mot en deux parties
      int splitPoint = word.length ~/ 2;
      return WordPair(
          word.substring(0, splitPoint), word.substring(splitPoint));
    }).toList();
    notifyListeners();
  }

  // Sauvegarder les favoris localement
  Future<void> _saveLocalFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favoriteStrings = favorites.map((pair) => pair.asLowerCase).toList();
    prefs.setStringList('favorites', favoriteStrings);
  }

  void getNext() {
    lastRemoved = null; // Réinitialiser quand on avance
    current = WordPair.random();
    notifyListeners();
  }

  // Bouton retour - récupérer le dernier mot
  bool goBack() {
    if (lastRemoved != null) {
      current = lastRemoved!;
      lastRemoved = null;
      notifyListeners();
      return true;
    }
    return false;
  }

  // Retourne true si ajouté, false si retiré
  bool toggleFavorite() {
    bool wasAdded;
    if (favorites.contains(current)) {
      favorites.remove(current);
      lastNotification = '"${current.asLowerCase}" retiré des favoris';
      wasAdded = false;
    } else {
      favorites.add(current);
      lastNotification = '"${current.asLowerCase}" ajouté aux favoris!';
      wasAdded = true;
    }
    _saveLocalFavorites(); // Sauvegarder localement
    notifyListeners();
    return wasAdded;
  }

  // Supprimer un favori spécifique
  void removeFavorite(WordPair pair) {
    favorites.remove(pair);
    _saveLocalFavorites();
    notifyListeners();
  }

  // Réajouter un favori (pour annuler suppression)
  void addFavorite(WordPair pair) {
    favorites.add(pair);
    _saveLocalFavorites();
    notifyListeners();
  }

  // Passer au suivant en sauvegardant le précédent
  void skipCurrent() {
    lastRemoved = current;
    current = WordPair.random();
    notifyListeners();
  }

  // Charger les favoris depuis le backend (désactivé)
  // Future<void> loadFavoritesFromBackend() async { ... }
  // Future<void> _addFavoriteToBackend(String word) async { ... }
  // Future<void> _removeFavoriteFromBackend(String word) async { ... }
}

class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();

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

    return Scaffold(
      body: SafeArea(
        child: Container(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: page,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (value) {
          setState(() {
            selectedIndex = value;
          });
        },
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Badge(
              label: Text('${appState.favorites.length}'),
              isLabelVisible: appState.favorites.isNotEmpty,
              child: Icon(Icons.favorite_outline),
            ),
            selectedIcon: Badge(
              label: Text('${appState.favorites.length}'),
              isLabelVisible: appState.favorites.isNotEmpty,
              child: Icon(Icons.favorite),
            ),
            label: 'Favoris',
          ),
        ],
      ),
    );
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
          // Bouton retour si disponible
          if (appState.lastRemoved != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextButton.icon(
                onPressed: () {
                  appState.goBack();
                },
                icon: Icon(Icons.undo),
                label: Text('Revenir au précédent'),
              ),
            ),
          SwipeableCard(pair: pair),
          SizedBox(height: 20),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Bouton Dislike
              IconButton.filled(
                onPressed: () {
                  appState.skipCurrent();
                },
                icon: Icon(Icons.close),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red.shade100,
                  foregroundColor: Colors.red,
                ),
              ),
              SizedBox(width: 15),
              // Bouton Like
              IconButton.filled(
                onPressed: () {
                  bool wasAdded = appState.toggleFavorite();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(appState.lastNotification ?? ''),
                      backgroundColor: wasAdded ? Colors.green : Colors.orange,
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  if (wasAdded) {
                    appState.skipCurrent();
                  }
                },
                icon: Icon(icon),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.green.shade100,
                  foregroundColor: Colors.green,
                ),
              ),
              SizedBox(width: 15),
              // Bouton Next
              IconButton.filled(
                onPressed: () {
                  appState.skipCurrent();
                },
                icon: Icon(Icons.arrow_forward),
                style: IconButton.styleFrom(
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          // Info tap pour définition
          Text(
            'Tap sur la carte pour voir la définition',
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onPrimaryContainer
                  .withValues(alpha: 0.6),
              fontSize: 12,
            ),
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

class _SwipeableCardState extends State<SwipeableCard>
    with SingleTickerProviderStateMixin {
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
    _animation =
        Tween<double>(begin: 0.0, end: 0.0).animate(_animationController);
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
    ))
      ..addListener(() {
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
    ))
      ..addListener(() {
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

      final response1 = await http.get(
          Uri.parse('https://api.dictionaryapi.dev/api/v2/entries/en/$word1'));
      final response2 = await http.get(
          Uri.parse('https://api.dictionaryapi.dev/api/v2/entries/en/$word2'));

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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              size: 80,
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            ),
            SizedBox(height: 20),
            Text(
              'Pas encore de favoris',
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Swipez à droite pour ajouter des mots !',
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onPrimaryContainer
                    .withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: appState.favorites.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              '${appState.favorites.length} favori${appState.favorites.length > 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }

        final pair = appState.favorites[index - 1];

        return Dismissible(
          key: Key(pair.asLowerCase),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: EdgeInsets.only(right: 20),
            child: Icon(
              Icons.delete,
              color: Colors.white,
            ),
          ),
          onDismissed: (direction) {
            appState.removeFavorite(pair);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('"${pair.asLowerCase}" supprimé'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 2),
              ),
            );
          },
          child: ListTile(
            leading: Icon(Icons.favorite, color: Colors.red),
            title: Text(pair.asLowerCase),
            trailing: IconButton(
              icon: Icon(Icons.delete_outline),
              onPressed: () {
                appState.removeFavorite(pair);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('"${pair.asLowerCase}" supprimé'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
