import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:async';

// USB Serial COnnection
import 'package:usb_serial/usb_serial.dart';
import 'package:usb_serial/transaction.dart';

// sound cue thing you know
import 'package:audioplayers/audioplayers.dart';
import 'package:audioplayers/audio_cache.dart';
import 'package:rflutter_alert/rflutter_alert.dart';

import 'package:flutter/services.dart';
import 'dart:io';

// tts thing
import 'package:flutter_tts/flutter_tts.dart';


// Google forms thing

import 'package:http/http.dart'as http;
void main() => runApp(MyApp());



class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}



enum TtsState { playing, stopped, paused, continued }
List<double> recordedTemp = [];
List recordedTime = [];

class _MyAppState extends State<MyApp> {
  //List _recordedTemp = [];

  AudioCache feverCache = AudioCache();
  bool measuringmode = false;
  int reading = 0;
  String displayReading = '0';
  String reading1 = '0';
  String reading2 = '0';
  String reading3 = '0';
  String reading4 = '0';
  UsbPort _port;
  String _status = "Idle";
  List<Widget> _ports = [];
  String _serialData = '0';
  //List<Widget> _serialData = [];
  StreamSubscription<String> _subscription;
  Transaction<String> _transaction;
  int _deviceId;
//  TextEditingController _textController = TextEditingController();
  String affirmation = "sound/Ting.mp3";

  FlutterTts flutterTts = FlutterTts();
      Future _error() async{
      var result = await flutterTts.speak('You cannot take temperature ');
      if (result == 1) setState(() => ttsState = TtsState.playing);
    }
    Future _starting() async {
        var result = await flutterTts.speak("Welcome to Tmap");
        if (result == 1) setState(() {
          ttsState = TtsState.playing ;
        });
    }
    // Sound cue for the 2 modes being activated
    Future _socialdistanceCue() async {
      if (measuringmode == true) {
        var result = await flutterTts.speak("Temperature Measuring Mode Activated");
        if (result == 1) setState(() => ttsState = TtsState.playing );
      }
      else{
        var result = await flutterTts.speak("Social Distancing Mode Activated");
        if (result == 1) setState(() => ttsState = TtsState.playing );
      }
    }
  Future _speak() async{
    if (double.parse(displayReading) < 37){
      //_onAlertPress(context);
      var result = await flutterTts.speak('your temperature is $displayReading');
      if (result == 1) setState(() => ttsState = TtsState.playing);
    } else if (double.parse(displayReading) >37 && double.parse(displayReading)  < 38){
      var result = await flutterTts.speak('your temperature is $displayReading, Moderate Fever Detected');
      if (result == 1) setState(() => ttsState = TtsState.playing);

    } else {
      var result = await flutterTts.speak('Warning High Fever Detected');
      if (result == 1) setState(() => ttsState = TtsState.playing);
    }
  }
  soundAffirmation(){
    feverCache.play(affirmation);
  }

  TtsState ttsState = TtsState.stopped;


  Future<bool> _connectTo(device) async {
    _serialData = '0';

    if (_subscription != null) {
      _subscription.cancel();
      _subscription = null;
    }

    if (_transaction != null) {
      _transaction.dispose();
      _transaction = null;
    }

    if (_port != null) {
      _port.close();
      _port = null;
    }

    if (device == null) {
      _deviceId = null;
      setState(() {
        _status = "Disconnected";
      });
      return true;
    }

    _port = await device.create();
    if (!await _port.open()) {
      setState(() {
        _status = "Failed to open port";
      });
      return false;
    }

    _deviceId = device.deviceId;
    await _port.setDTR(true);
    await _port.setRTS(true);
    await _port.setPortParameters(
        115200, UsbPort.DATABITS_8, UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);

    _transaction = Transaction.stringTerminated(
        _port.inputStream, Uint8List.fromList([13, 10]));

    _subscription = _transaction.stream.listen((String line) {
      setState(() {
        _serialData = line;
        reading1 = _serialData.split(' ')[1];
        reading2 = _serialData.split(' ')[0];
        if (double.parse(reading1) != 0.0){
          displayReading = reading1;
          _speak();
        }
      });
    });

    setState(() {
      _status = "Connected";
    });
    return true;
  }

  void _getPorts() async {
    _ports = [];
    List<UsbDevice> devices = await UsbSerial.listDevices();
    print(devices);

    devices.forEach((device) {
      _ports.add(ListTile(
          leading: Icon(Icons.usb),
          title: Text(device.productName),
          subtitle: Text(device.manufacturerName),
          trailing: RaisedButton(
            child:
                Text(_deviceId == device.deviceId ? "Disconnect" : "Connect"),
            onPressed: () {
              _connectTo(_deviceId == device.deviceId ? null : device)
                  .then((res) {
                _getPorts();
              });
            },
          )));
    });

    setState(() {
      print(_ports);
    });
  }

  @override
  void initState() {
    WidgetsFlutterBinding.ensureInitialized();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitDown,DeviceOrientation.portraitUp]);
    feverCache.load(affirmation);
    _starting();
    super.initState();
    UsbSerial.usbEventStream.listen((UsbEvent event) {
      _getPorts();
    });


    _getPorts();
  }

  @override
  void dispose() {
    super.dispose();
    _connectTo(null);
  }


  _onBasicAlertPressed(context) {
    Alert(
        context: context,
        title: "RFLUTTER ALERT",
        desc: "Flutter is more awesome with RFlutter Alert.")
        .show();
  }



  @override
  Widget build(BuildContext context) {

    bool fever = double.parse(displayReading) < 38 ? false : true;
    return MaterialApp(
      theme: ThemeData(
        primaryColor: fever == true ? Colors.redAccent : Colors.blueAccent,
        //brightness: Brightness.values[1],
        textTheme: TextTheme(bodyText2: TextStyle(color: Colors.black)),
        colorScheme : ColorScheme.fromSwatch()
      ),
      home: buildHomePage("TMOM Data Menu"),
      debugShowCheckedModeBanner: false,
    );
  }




  Widget buildHomePage( String title) {

    // basic conditionary checker
    String accuracytext = '0';
    if (double.parse(reading2) <= 2.0){
      accuracytext = "Accurate";
    }else if(double.parse(reading2) > 3.0){
      accuracytext = 'Inaccurate!';
    }



    //key
    final _scaffoldKey = GlobalKey<ScaffoldState>();


    // snackbar feature thing
    _showSnackbar(String message) {
      final snackBar = SnackBar(content: Text(message));
      _scaffoldKey.currentState.showSnackBar(snackBar);
    }

    // How it sends data to backend
    Future<void> submitData() async {
      const String URL =
          "https://script.google.com/macros/s/AKfycbw5gNlNr4XKCqZ3iXBIdgWSLJPeWlVH58MVMSEdd9bPKluJpe4/exec";
      _showSnackbar("Syncing Google Form");
      var response = await http.get(URL +"?temperature=$displayReading");
      if (response.statusCode == "SUCCESS") {
        _showSnackbar("Data Transferred");
      }else{
        _showSnackbar("Error Transfering Data");
      }
    }
    // State of perpetual panic or not panic
    bool fever = double.parse(displayReading) < 38 ? false : true;

      if  (double.parse(displayReading) < 37){
        
        //_onAlertPress(context);
      }

    // BOPX STUFF
    final defaultBoxStyle = BoxDecoration(
//      gradient: LinearGradient(
//          begin: Alignment.topRight,
//          end: Alignment.bottomLeft,
//          colors: [Colors.blue, Colors.red]
//      );
      color: Color.fromRGBO(213, 229, 255, 1),
      border: Border.all(
        color: Color.fromRGBO(0, 229, 255, 1),
        width:2,
      ),
      borderRadius: BorderRadius.all(
        Radius.circular(15),
      ),
    );

    final defaultBoxStyleModified = BoxDecoration(
      color: Color.fromRGBO(147, 233, 255, 1),
      border: Border.all(
        color: Color.fromRGBO(147, 233, 255, 1),
        width:5,
      ),
      borderRadius: BorderRadius.all(
        Radius.circular(30),
      ),
    );
    // at reading
    final defaultBoxStyleModified1 = BoxDecoration(
      color: Color.fromRGBO(255, 255, 255, 1),
      border: Border.all(
        color: Color.fromRGBO(255, 255, 255, 1),
        width:2,
      ),
      borderRadius: BorderRadius.all(
        Radius.circular(2),
      ),
    );


    final thermometerReading = Container(
      decoration: defaultBoxStyleModified1,
      padding: EdgeInsets.all(5),
     // decoration: defaultBoxStyle,
      child: Text(
        //'$_serialData °C',
        measuringmode == false ? '- °C' : '$displayReading °C',
        style: TextStyle(
          color: (fever == true ? Colors.red : Colors.black),
          fontSize: 50,
        ),  
      ),
    );

    final distanceReading = Container(
      decoration: defaultBoxStyleModified1,
      padding: EdgeInsets.all(5),
      child: Text(
        measuringmode == false ? '$reading2 cm' : '$reading2 cm',
        style: TextStyle(
          fontSize: 50,
        ),
      ),
    );



    final descTextStyle = TextStyle(
      color: Colors.black,
      fontWeight: FontWeight.w800,
      fontFamily: 'Roboto',
      letterSpacing: 0.5,
      fontSize: 10,
      height: 2,
    );


    // Its in the name man
    final thermometerIcons = DefaultTextStyle.merge(
      style: descTextStyle,
      child: Container(
          decoration: defaultBoxStyle,
        padding: EdgeInsets.all(10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Column(
              children: [
                IconButton(
                  color: Colors.green,
                  icon: Icon(Icons.add_box),
                  tooltip: "Records Temperature",
                  onPressed: (){
                    if (measuringmode == true){
                      String data ='H\r\n'  ;
                      _port.write(Uint8List.fromList(data.codeUnits));
                      AudioPlayer.logEnabled = true;
                      soundAffirmation();
                      //_onAlertPress(context);
                    }
                    else{
                      _error();
                    }
                    setState(() {
                    });
                  },
                ),
                Text(
                  "Record Temperature",
                  style: descTextStyle,
                ),
              ],
            ),
            Column(
              children: [
                Builder(
                  builder: (context) => IconButton(
                    color: Colors.green,
                    icon: Icon(Icons.assessment),
                    tooltip: "Sends Recorded Data to gdrive",
                    onPressed: (){
                      submitData();
//                      Navigator.push(
//                          context,
//
//                          MaterialPageRoute(builder: (context) => DataLog())
//                      );
                    },
                  ),
                ),
                Text("Upload Log"),
              ],
            ),
          ],
        ),
      ),
    );
    final distanceIcons = DefaultTextStyle.merge(
      style: descTextStyle,
      child: Container(
        decoration: defaultBoxStyle,
        padding: EdgeInsets.all(20),

        //color: Colors.redAccent,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Column(
              children: [
                IconButton(
                  color: Colors.green,
                  icon: Icon(Icons.power_settings_new),
                  tooltip: "Turns on Measuring Mode",
                  onPressed: () {
                    setState(() {
                      measuringmode = measuringmode == true ? false : true;
                      _socialdistanceCue();
                    });
                  },
                ),
                Text(
                  measuringmode == true ? "Turn Off" : "Turn On",
                  style: descTextStyle,
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (double.parse(reading2) < 1.0){
      //playNoFever();
    }

    // The container that does the warning msgs
    final WarningContainer = Container(
      padding: EdgeInsets.all(1),
      child: Text(
        accuracytext,
        style: TextStyle(
          color: double.parse(reading2) < 1.0 ? Colors.green : Colors.red,
          fontSize: 20,
        ),
      ),
    );

    //  The one that does not contain the warning msgs
    final test1container = Container(
      padding: EdgeInsets.all(1),
      child: Text(
        "",
        style: TextStyle(
          fontSize: 0,
        ),
      ),
    );

    // Window for temperature sensor
    final firstWindow = Container(
      //color: Colors.transparent,
      decoration: defaultBoxStyleModified,
      child: Column(
        children: [
          thermometerReading,
          thermometerIcons,

        ],
      ),
    );

    // Window for distance sensor
    final secondWindow = Container(

      decoration: defaultBoxStyleModified,
      child: Column(
        children: [
          distanceReading,
          measuringmode == true ? WarningContainer : test1container,
          distanceIcons,
        ],
      ),
    );

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: fever == true ? Color.fromRGBO(255, 182, 193, 1) : Color.fromRGBO(213, 229, 255, 1),
      appBar: AppBar(
          title: Text(title),
          centerTitle: true,
      ),

      body: Center(
        child: Column(
          children: [
            Text(
                _ports.length > 0
                    ? "Available Serial Ports"
                    : "Device not connected!",
                style: Theme.of(context).textTheme.title),
            ..._ports,
            Text('Status: $_status\n'),
//            Text("Result Data", style: Theme.of(context).textTheme.title),
//            ..._serialData,
            Container(
              padding: EdgeInsets.all(5),
              color: Colors.transparent,
              child: Container(
                //decoration: defaultBoxStyle,
                //color: Colors.transparent,
                child: firstWindow,
              ),
            ),
            Container(
              padding: EdgeInsets.all(5),
              color: Colors.transparent,
              child: Container(
                child: secondWindow,
              ),
            ),
          ],
        ),
      ),
        bottomNavigationBar: BottomAppBar(
          color: Colors.transparent,
          elevation: 0.0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    " TMom totally© 2020",
                    style: TextStyle(fontSize: 15, color: Colors.black45),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            ],
          ),
        ),
    );
  }
}

