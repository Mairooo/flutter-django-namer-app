import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:convert';

// Couleurs de l'application style Alerte
class AppColors {
  static const Color background = Color(0xFF1A1A2E);
  static const Color backgroundLight = Color(0xFF252542);
  static const Color primary = Color(0xFFE91E63);      // Rose Sigma
  static const Color primaryLight = Color(0xFFFF4081); // Rose clair
  static const Color white = Colors.white;
  static const Color grey = Color(0xFF8E8E93);
  static const Color darkGrey = Color(0xFF3A3A4A);
}

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
        title: 'Sigma App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: AppColors.background,
          colorScheme: ColorScheme.dark(
            primary: AppColors.primary,
            secondary: AppColors.primaryLight,
            surface: AppColors.backgroundLight,
            onSurface: AppColors.white,
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
          ),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: AppColors.backgroundLight,
            indicatorColor: AppColors.primary.withValues(alpha: 0.2),
            labelTextStyle: WidgetStateProperty.all(
              TextStyle(color: AppColors.white, fontSize: 12),
            ),
          ),
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
  
  // Stocker les coordonnées GPS
  Position? lastPosition;

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

  // Obtenir et sauvegarder la localisation
  Future<String> saveLocation() async {
    try {
      // Vérifier si les services de localisation sont activés
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return 'Services de localisation désactivés';
      }

      // Vérifier les permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return 'Permission de localisation refusée';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return 'Permission refusée définitivement';
      }

      // Obtenir la position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      lastPosition = position;
      
      // Sauvegarder dans SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('last_latitude', position.latitude);
      await prefs.setDouble('last_longitude', position.longitude);
      await prefs.setString('last_location_time', DateTime.now().toIso8601String());

      notifyListeners();
      return 'Position enregistrée:\nLat: ${position.latitude.toStringAsFixed(4)}\nLon: ${position.longitude.toStringAsFixed(4)}';
    } catch (e) {
      return 'Erreur: $e';
    }
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
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.background,
              AppColors.backgroundLight,
              AppColors.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header avec logos
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/sigma_logo.png',
                      height: 100,
                    ),
                    SizedBox(width: 24),
                    SvgPicture.asset(
                      'assets/images/LOGO METRO.svg',
                      height: 90,
                      colorFilter: ColorFilter.mode(
                        AppColors.white,
                        BlendMode.srcIn,
                      ),
                    ),
                  ],
                ),
              ),
              // Contenu principal
              Expanded(child: page),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundLight,
          border: Border(top: BorderSide(color: AppColors.darkGrey, width: 0.5)),
        ),
        child: NavigationBar(
          backgroundColor: Colors.transparent,
          selectedIndex: selectedIndex,
          onDestinationSelected: (value) {
            setState(() {
              selectedIndex = value;
            });
          },
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.home_outlined, color: AppColors.grey),
              selectedIcon: Icon(Icons.home, color: AppColors.primary),
              label: 'Accueil',
            ),
            NavigationDestination(
              icon: Badge(
                label: Text('${appState.favorites.length}'),
                backgroundColor: AppColors.primary,
                isLabelVisible: appState.favorites.isNotEmpty,
                child: Icon(Icons.favorite_outline, color: AppColors.grey),
              ),
              selectedIcon: Badge(
                label: Text('${appState.favorites.length}'),
                backgroundColor: AppColors.primary,
                isLabelVisible: appState.favorites.isNotEmpty,
                child: Icon(Icons.favorite, color: AppColors.primary),
              ),
              label: 'Favoris',
            ),
          ],
        ),
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          SizedBox(height: 24),
          // Texte d'instruction
          Text(
            'Découvrez de nouveaux mots',
            style: TextStyle(
              color: AppColors.grey,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Swipez pour explorer',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 48),
          // Carte principale
          SwipeableCard(pair: pair),
          SizedBox(height: 48),
          // Boutons d'action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _CircleActionButton(
                icon: Icons.close_rounded,
                label: 'Passer',
                color: Color(0xFFE57373),
                onTap: () => appState.skipCurrent(),
              ),
              _CircleActionButton(
                icon: icon,
                label: 'Favori',
                color: AppColors.primary,
                onTap: () {
                  bool wasAdded = appState.toggleFavorite();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(appState.lastNotification ?? ''),
                      backgroundColor: wasAdded ? AppColors.primary : Colors.orange,
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      margin: EdgeInsets.all(16),
                    ),
                  );
                  if (wasAdded) {
                    appState.skipCurrent();
                  }
                },
              ),
              _CircleActionButton(
                icon: Icons.location_on_rounded,
                label: 'Position',
                color: Color(0xFFFFB74D),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LocationPage()),
                  );
                },
              ),
              _CircleActionButton(
                icon: Icons.arrow_forward_rounded,
                label: 'Suivant',
                color: AppColors.primaryLight,
                onTap: () => appState.skipCurrent(),
              ),
            ],
          ),
          SizedBox(height: 24),
          // Info tap pour définition
          Text(
            'Appuyez sur la carte pour voir la définition',
            style: TextStyle(
              color: AppColors.grey,
              fontSize: 12,
            ),
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }
}

// Bouton circulaire
class _CircleActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CircleActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(35),
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
                color: color.withValues(alpha: 0.1),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
          ),
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: AppColors.grey,
            fontSize: 11,
          ),
        ),
      ],
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
            color: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 40),
              child: Text(
                widget.pair.asLowerCase,
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
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
              color: AppColors.primary.withValues(alpha: 0.3),
            ),
            SizedBox(height: 20),
            Text(
              'Pas encore de favoris',
              style: TextStyle(
                fontSize: 18,
                color: AppColors.white,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Swipez à droite pour ajouter des mots !',
              style: TextStyle(
                color: AppColors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16),
      itemCount: appState.favorites.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '${appState.favorites.length} favori${appState.favorites.length > 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.white,
              ),
            ),
          );
        }

        final pair = appState.favorites[index - 1];

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Dismissible(
            key: Key(pair.asLowerCase),
            direction: DismissDirection.endToStart,
            background: Container(
              decoration: BoxDecoration(
                color: Color(0xFFE57373),
                borderRadius: BorderRadius.circular(12),
              ),
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
                  backgroundColor: Color(0xFFE57373),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  margin: EdgeInsets.all(16),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.darkGrey),
              ),
              child: ListTile(
                leading: Icon(Icons.favorite, color: AppColors.primary),
                title: Text(
                  pair.asLowerCase,
                  style: TextStyle(color: AppColors.white),
                ),
                trailing: IconButton(
                  icon: Icon(Icons.delete_outline, color: AppColors.grey),
                  onPressed: () {
                    appState.removeFavorite(pair);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('"${pair.asLowerCase}" supprimé'),
                        backgroundColor: Color(0xFFE57373),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        margin: EdgeInsets.all(16),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Page de localisation
class LocationPage extends StatefulWidget {
  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  Position? _position;
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _locationTime;

  @override
  void initState() {
    super.initState();
    _loadSavedLocation();
  }

  // Charger la dernière position sauvegardée
  Future<void> _loadSavedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('last_latitude');
    final lon = prefs.getDouble('last_longitude');
    final timeStr = prefs.getString('last_location_time');
    
    if (lat != null && lon != null) {
      setState(() {
        _position = Position(
          latitude: lat,
          longitude: lon,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
        if (timeStr != null) {
          _locationTime = DateTime.parse(timeStr);
        }
      });
    }
  }

  // Obtenir la position actuelle
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _errorMessage = 'Services de localisation desactives';
          _isLoading = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _errorMessage = 'Permission de localisation refusee';
            _isLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage = 'Permission refusee definitivement';
          _isLoading = false;
        });
        return;
      }

      // Obtenir la position avec haute precision (quelques metres)
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      // Sauvegarder
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('last_latitude', position.latitude);
      await prefs.setDouble('last_longitude', position.longitude);
      await prefs.setString('last_location_time', DateTime.now().toIso8601String());

      setState(() {
        _position = position;
        _locationTime = DateTime.now();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur: $e';
        _isLoading = false;
      });
    }
  }

  // Ouvrir Google Maps
  Future<void> _openInGoogleMaps() async {
    if (_position == null) return;
    
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${_position!.latitude},${_position!.longitude}'
    );
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible d\'ouvrir Google Maps'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ma Position'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icone
              Icon(
                Icons.location_on,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              SizedBox(height: 30),
              
              // Affichage des coordonnees
              if (_isLoading)
                Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Localisation en cours...'),
                  ],
                )
              else if (_errorMessage != null)
                Card(
                  color: Colors.red.shade100,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red.shade900),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else if (_position != null)
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Text(
                          'Coordonnees GPS',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        SizedBox(height: 16),
                        _buildCoordinateRow('Latitude', _position!.latitude.toStringAsFixed(6)),
                        SizedBox(height: 8),
                        _buildCoordinateRow('Longitude', _position!.longitude.toStringAsFixed(6)),
                        SizedBox(height: 8),
                        _buildCoordinateRow('Precision', '${_position!.accuracy.toStringAsFixed(1)} m'),
                        if (_locationTime != null) ...[
                          SizedBox(height: 8),
                          _buildCoordinateRow(
                            'Heure',
                            '${_locationTime!.hour.toString().padLeft(2, '0')}:${_locationTime!.minute.toString().padLeft(2, '0')}:${_locationTime!.second.toString().padLeft(2, '0')}'
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              else
                Text(
                  'Appuyez sur le bouton pour obtenir votre position',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              
              SizedBox(height: 30),
              
              // Bouton actualiser
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _getCurrentLocation,
                icon: Icon(Icons.my_location),
                label: Text(_position == null ? 'Obtenir ma position' : 'Actualiser'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              
              SizedBox(height: 16),
              
              // Bouton Google Maps
              if (_position != null)
                ElevatedButton.icon(
                  onPressed: _openInGoogleMaps,
                  icon: Icon(Icons.map),
                  label: Text('Voir sur Google Maps'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoordinateRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade600,
          ),
        ),
        SelectableText(
          value,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
