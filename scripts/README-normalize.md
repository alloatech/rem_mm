Logo Normalization Script

This repository includes `scripts/normalize_logos.sh` to create normalized helmet-style logo chips for NFL team logos.

Why use it
- Some logos are dark and disappear on dark backgrounds.
- Some logos are light and lose contrast on light backgrounds.
- Normalizing provides consistent visual chips and avoids runtime processing.

Requirements
- ImageMagick (convert, identify) installed on your system
  - macOS: `brew install imagemagick`
- curl

Usage
1. Make the script executable:

   chmod +x scripts/normalize_logos.sh

2. Run the script and point to an output directory:

   ./scripts/normalize_logos.sh assets/normalized_logos

3. The script downloads example team logos and writes normalized PNGs to the output folder.

Integration
- Add the generated files to your Flutter assets in `pubspec.yaml`:

  flutter:
    assets:
      - assets/normalized_logos/

- Replace runtime image URLs in `roster_detail_page.dart` with the new asset path, or host the normalized images in your CDN.

Notes and improvements
- You can expand the `TEAMS` list in the script or provide a file with team codes.
- Instead of a simple mean brightness test, you can run a palette-based contrast check (dominant color vs. background) for better results.
- The script currently composites a circular background and adds a thin stroke; tweak the colors as needed.
