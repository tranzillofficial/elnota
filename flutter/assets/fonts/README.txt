Download the Cairo font family from:
https://fonts.google.com/specimen/Cairo

Place the following files in this directory before building:
  - Cairo-Regular.ttf    (weight 400)
  - Cairo-Medium.ttf     (weight 500)
  - Cairo-SemiBold.ttf   (weight 600)
  - Cairo-Bold.ttf       (weight 700)

The font is declared in pubspec.yaml under flutter → fonts → Cairo.
Without the .ttf files the app will build but will fall back to the system default font.
