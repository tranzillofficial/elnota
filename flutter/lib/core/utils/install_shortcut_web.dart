import 'dart:js_interop';

@JS('elnotaInstallShortcut')
external JSPromise<JSString> _installShortcut();

Future<String> installShortcut() async =>
    (await _installShortcut().toDart).toDart;
