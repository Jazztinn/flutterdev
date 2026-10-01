import 'activity_placeholder.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

// show activity one.
class ActivityOnePage extends StatefulWidget {
  final String title;

  const ActivityOnePage({super.key, required this.title});

  @override
  _MusicPlayerState createState() => _MusicPlayerState();
}

class _MusicPlayerState extends State<ActivityOnePage> {
  final AudioPlayer _player = AudioPlayer();
  List<String> songs = [
    'assets/music/less.mp3',
    'assets/music/maggotsforbrains.mp3',
  ];

  int _currentIndex = 0;
  bool _isPlaying = false;

  //play selected music
  Future<void> _playSong(int index) async {
    await _player.stop();
    await _player.play(AssetSource(songs[index]));
    setState(() {
      _currentIndex = index;
      _isPlaying = true;
    });
  }

  //pause/resume music
  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await _player.pause();
      setState(() {
        _isPlaying = false;
      });
    } else {
      await _player.resume();
      setState(() {
        _isPlaying = true;
      });
    }  
  }

  //next music
  Future<void> _nextSong() async {
    int nextIndex = (_currentIndex + 1) % songs.length;
    await _playSong(nextIndex);
  }

  //previous music
  Future<void> _previousSong() async {
    int previousIndex = (_currentIndex - 1 + songs.length) % songs.length;
    await _playSong(previousIndex);
  }

  //compost 
  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
  
  @override 
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton (
            icon: Icon(Icons.search),
            onPressed: (){
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SongListScreen(
                  songs: songs,
                  onSongSelected: (index) {
                    _playSong(index);
                    Navigator.pop(context);
                  },
                ),
              ),
            );
          }), //IconButton
        ], 
      ), //AppBar
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              songs[_currentIndex],
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ), // display current song name
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.play_arrow_rounded),
                  onPressed: _togglePlayPause,
                  iconSize: 40,
                ), 
                IconButton(
                  icon: Icon(Icons.skip_next),
                  onPressed: _nextSong,
                  iconSize: 40,
                ),
                IconButton(
                  icon: Icon(Icons.skip_previous),
                  onPressed: _previousSong,
                  iconSize: 40,
                ),
              ]
            ), // Row
          ]
        ),
      ), // Center
    ); // Scaffold
  }
}


class SongListScreen extends StatelessWidget {
  final List<String> songs;
  final Function(int) onSongSelected;

  const SongListScreen({
    super.key, 
    required this.songs, 
    required this.onSongSelected
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select a Song')),
      body: ListView.builder(
        itemCount: songs.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(songs[index]),
            onTap: () => onSongSelected(index),
          );
        },
      ),
    );
  }
}

