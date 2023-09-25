import 'dart:convert';
import 'dart:async';

import 'package:digital_scale/digital_scale.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:roundabnt/round_abnt.dart';

// ignore: must_be_immutable
class DigitalScale implements DigitalScaleImplementation {
  final String digitalScalePort;
  final String digitalScaleModel;
  final int digitalScaleRate;
  final int digitalScaleTimeout;
  static late SerialPort serialPort;
  static late SerialPortReader serialPortReader;
  static int factor = 1;
  static String initString = '';

  int? stopBitss;

  int? bitss;

  int? paritys;

  /// initialize the serial port and call methods
  DigitalScale(
      {required this.digitalScalePort,
      required this.digitalScaleModel,
      required this.digitalScaleRate,
      required this.digitalScaleTimeout,
      String? initStringg,
      int? factorr,
      int? stopBitss,
      int? bitss,
      int? paritys}) {
    serialPort = SerialPort(digitalScalePort);

    if (initStringg != null) {
      initString = initStringg;
    }

    if (factorr != null) {
      factor = factorr;
    }

    if (stopBitss != null) {
      this.stopBitss = stopBitss;
    }

    if (bitss != null) {
      this.bitss = bitss;
    }

    if (paritys != null) {
      this.paritys = paritys;
    }

    bool resp = open();

    if (resp) {
      try {
        config();
        writeInPort(initString);
        readPort();
      } catch (_) {}
    }
  }

  /// Open the port for Read and Write
  @override
  bool open() {
    if (serialPort.isOpen) {
      try {
        serialPort.close();
      } catch (_) {}
    }

    if (!serialPort.isOpen) {
      if (!serialPort.openReadWrite()) {
        return false;
      }
    }

    return true;
  }

  /// Configure the port with arguments
  @override
  config() {
    int stopBits;
    int bits;
    int parity;

    switch (digitalScaleModel.toLowerCase()) {
      case 'other':
        stopBits = stopBitss!;
        bits = bitss!;
        parity = paritys!;
        break;
      case 'toledo prix 3':
        initString = String.fromCharCode(5) + String.fromCharCode(13);
        factor = 1000;
        stopBits = 1;
        bits = 8;
        parity = 0;
        break;
      case 'urano pop light':
        initString = String.fromCharCode(5) +
            String.fromCharCode(10) +
            String.fromCharCode(13);
        factor = 1;
        stopBits = 2;
        bits = 8;
        parity = 0;
        break;
      case 'elgin dp1502':
      default:
        initString = String.fromCharCode(5) +
            String.fromCharCode(10) +
            String.fromCharCode(13);
        factor = 1;
        stopBits = 1;
        bits = 8;
        parity = 0;
    }

    SerialPortConfig config = serialPort.config;
    config.baudRate = digitalScaleRate;
    config.stopBits = stopBits;
    config.bits = bits;
    config.parity = parity;
    serialPort.config = config;
  }

  /// write enq in port
  @override
  writeInPort(String value) {
    try {
      serialPort.write(utf8.encoder.convert(value));
    } catch (_) {}
  }

  /// read the port
  @override
  readPort() {
    try {
      serialPortReader = SerialPortReader(serialPort);
    } catch (_) {}
  }

  /// create the listener and return the weight
  @override
  Future<double> getWeight() async {
    RoundAbnt roundAbnt = RoundAbnt();
    var completer = Completer<double>();
    Map<String, ValueNotifier<double>> mapData = {};
    String decodedWeight = '';
    bool enterListen = false;

    try {
      double weight = 0.00;
      serialPortReader.stream.listen((data) async {
        decodedWeight += utf8.decode(data);

        if (digitalScaleModel.toLowerCase() == 'urano pop light') {
          int n0 = utf8.decode(data).indexOf('N0') + 2;
          int kg = utf8.decode(data).indexOf('kg');
          decodedWeight = utf8
              .decode(data)
              .substring(n0, kg)
              .trim()
              .replaceAll(',', '.')
              .trim();
        } else {
          decodedWeight = utf8
              .decode(data)
              .substring(1, (utf8.decode(data).length - 1))
              .trim();
        }
        enterListen = true;

        weight = ((double.parse(decodedWeight)) / factor);
        weight = roundAbnt.roundAbnt('$weight', 3);

        mapData['weight'] = ValueNotifier<double>(weight);

        completer.complete(mapData['weight']?.value);
        completer.future;
      });

      await Future.delayed(Duration(milliseconds: digitalScaleTimeout), () {
        serialPort.close();
        return weight;
      });

      if (!enterListen) {
        if (digitalScaleModel.toLowerCase() == 'urano pop light') {
          int n0 = decodedWeight.indexOf('N0') + 2;
          int kg = decodedWeight.indexOf('kg');
          decodedWeight = decodedWeight
              .substring(n0, kg)
              .trim()
              .replaceAll(',', '.')
              .trim();
          enterListen = true;
        } else {
          decodedWeight =
              decodedWeight.substring(1, (decodedWeight.length - 1)).trim();
        }

        weight = ((double.parse(decodedWeight)) / factor);
        weight = roundAbnt.roundAbnt('$weight', 3);

        mapData['weight'] = ValueNotifier<double>(weight);
        completer.complete(mapData['weight']?.value);
        completer.future;
      }

      return weight;
    } catch (e) {
      if (kDebugMode) {
        print('digital scale error: $e');
      }
      return -99.99;
    }
  }
}
