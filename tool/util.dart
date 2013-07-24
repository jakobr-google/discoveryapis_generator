library discovery_api_client_generator.util;

import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as pathos;
import 'package:bot_io/bot_io.dart';
import 'package:hop/hop.dart';

// TODO: put this in bot_io
// https://github.com/kevmoo/bot_io.dart/issues/4
Future withTempDir(Future func(Directory dir)) {
  TempDir tmpDir;

  return TempDir.create()
      .then((value) {
        tmpDir = value;

        return func(tmpDir.dir);
      })
      .whenComplete(() {
        if(tmpDir != null) {
          tmpDir.dispose();
        }
      });
}

List<String> getLibraryPaths(String rootDir, String shortName) {
  final libDir = 'dart_${shortName}_client/lib';

  var files = [];

  files.addAll(['', '_browser', '_console']
    .map((k) => 'src/cloud_api${k}.dart'));

  files.addAll(['console', 'browser', 'client']
    .map((k) => '${shortName}_${k}.dart'));

  return files
      .map((f) => pathos.join(rootDir, libDir, f))
      .toList(growable: false);
}

Future analyzePackage(String rootDir, String shortName,
                      bool continueOnFail) {
  var libraryPaths = getLibraryPaths(rootDir, shortName);

  assert(libraryPaths.length == 6);

  final packageDir = pathos.join(rootDir, 'dart_${shortName}_client');

  _logMessage('installing packages at $packageDir');

  return Process.run('pub', ['--trace', 'install'], workingDirectory: packageDir)
      .then((ProcessResult pr) {
        if(pr.exitCode != 0) {
          throw new Exception('''Pub install failed.
$packageDir
${pr.stdout}
${pr.stderr}''');
        }
        _logMessage('pub install worked');

        final packagesDir = pathos.join(packageDir, 'packages');

        return Future.forEach(libraryPaths, (path) =>
            _analyzeLib(packagesDir, path, continueOnFail));
      });
}

Future<bool> _analyzeLib(String packageDir, String libPath,
    bool continueOnFail) {
  _logMessage('analyzing $libPath');

  var args = ['--package-root', packageDir, libPath];

  return Process.run('dartanalyzer', args)
      .then((ProcessResult pr) {
        var success = pr.exitCode == 0;
        if(!success && !continueOnFail) {
            throw new Exception('Analysis failed for $libPath');
        }
        _logMessage('analyze completed');
      });
}

void _logMessage(String msg) {
  //TODO: really use logging?
  //print(msg);
}