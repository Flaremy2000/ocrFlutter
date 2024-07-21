import 'package:flutter/material.dart';
import 'package:ocr/Profile/profile.dart';
import 'package:ocr/Tools/tools.dart';
import 'package:ocr/UploadFile/upload_file.dart';
import 'package:ocr/UserGesture/user_gesture.dart';
import 'package:ocr/home/home.dart';
import 'package:ocr/providers/auth_provider.dart';
import 'package:provider/provider.dart';

class MainScreen extends StatefulWidget{
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>{
  int _selectedIndex = 0;

  static final List<Widget> _widgetOptions = <Widget>[
    const Home(),
    const UploadFile(),
    const Profile(),
    const Tools(),
    const UserGesture(),
  ];

  void _onItemTapped(int index){
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return WebMainScreen(selectedIndex: _selectedIndex, onItemTapped: _onItemTapped);
  }

}

class WebMainScreen extends StatelessWidget{
  final int selectedIndex;
  final Function(int) onItemTapped;

  const WebMainScreen({required this.selectedIndex, required this.onItemTapped, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF3F8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: SizedBox(
                        width: double.infinity,
                        height: 200,
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Container(
                            decoration: const BoxDecoration(
                              image: DecorationImage(
                                image: AssetImage('assets/images/logo.png'),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ListTile(
              leading: const Icon(Icons.home, color: Color(0xFF0F33B4),),
              title: const Text('Inicio', style: TextStyle(color: Color(0xC3000022)) ),
              onTap: () {
                onItemTapped(0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file, color: Color(0xFF0F33B4),),
              title: const Text('Carpetas', style: TextStyle(color: Color(0xC3000022)) ),
              onTap: () {
                onItemTapped(1);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: Color(0xFF0F33B4),),
              title: const Text('Perfil', style: TextStyle(color: Color(0xC3000022)) ),
              onTap: () {
                onItemTapped(2);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.build, color: Color(0xFF0F33B4),),
              title: const Text('Herramientas', style: TextStyle(color: Color(0xC3000022)) ),
              onTap: () {
                onItemTapped(3);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.social_distance_outlined, color: Color(0xFF0F33B4),),
              title: const Text('Gestión de usuario', style: TextStyle(color: Color(0xC3000022)) ),
              onTap: () {
                onItemTapped(4);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: const Text('OCR', style: TextStyle(color: Color(0xFFFFF3F8)),),
        iconTheme: const IconThemeData(color: Color(0xFFFFF3F8)),
        backgroundColor: const Color(0xFF0F33B4),
        actions: [
          _buildPopupMenu(context),
        ],
      ),
      body: Center(
        child: _MainScreenState._widgetOptions.elementAt(selectedIndex),
      ),
    );
  }

    Widget _buildPopupMenu(BuildContext context) {
    return PopupMenuButton<String>(
      color: const Color(0xFFFFF3F8),
      icon: Container(
        padding: const EdgeInsets.all(8), 
        margin: const EdgeInsets.only(right: 5),
        decoration: const BoxDecoration(
          color:  Color(0xFFFFF3F8),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.person, color: Color(0xFF0F33B4)),
      ),
      onSelected: (value) {
        if (value == 'Perfil') {
          _navigateToProfile(context);
        } else if (value == 'Cerrar sesión') {
          _logout(context);
        }
      },
      itemBuilder: (BuildContext context) {
        Set<String> menuOptions = {'Perfil', 'Cerrar sesión'};
        return menuOptions.map((choice) {
          return PopupMenuItem<String>(
            value: choice,
            child: Text(choice, style: const TextStyle(color: Color(0xC3000022)),),
          );
        }).toList();
      },
    );
  }

    void _navigateToProfile(BuildContext context) {
    final mainScreenState = context.findAncestorStateOfType<_MainScreenState>();
    if (mainScreenState != null) {
      mainScreenState._onItemTapped(2);
    }
  }

  void _logout(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.logout();
    Navigator.pushReplacementNamed(context, '/');
  }

}