import 'dart:math';

/// Generates Diceware-style passphrases for sealed exports — meant to
/// be read aloud over a phone call or sent as a text, not typed from
/// memory like a normal password.
///
/// This is a curated 256-word list (8 bits of entropy per word), not
/// the full 7,776-word EFF Diceware list — chosen for words that are
/// short, common, and hard to mishear aloud. Swapping in the full EFF
/// list later would raise entropy per word from 8 bits to ~12.9 bits
/// without changing anything else about how this class is used.
class PassphraseGenerator {
  PassphraseGenerator._();

  static const words = [
    'apple', 'river', 'stone', 'cloud', 'eagle', 'amber', 'bronze', 'copper', 'desert', 'forest',
    'garden', 'harbor', 'island', 'jungle', 'kettle', 'ladder',
    'maple', 'nectar', 'oasis', 'pepper', 'rabbit', 'saddle', 'tunnel', 'valley', 'walnut', 'yellow',
    'zebra', 'anchor', 'basket', 'candle', 'dagger', 'falcon',
    'granite', 'hammer', 'ivory', 'jacket', 'kitten', 'lantern', 'marble', 'needle', 'orchid', 'pigeon',
    'quilt', 'ribbon', 'saffron', 'thunder', 'usher', 'velvet',
    'willow', 'yogurt', 'zephyr', 'almond', 'barrel', 'cactus', 'dolphin', 'emerald', 'feather', 'goose',
    'harvest', 'iguana', 'jasmine', 'kernel', 'lagoon', 'meadow',
    'nickel', 'otter', 'panther', 'quiet', 'raven', 'summit', 'temple', 'unicorn', 'violet', 'walrus',
    'yarrow', 'zinnia', 'acorn', 'breeze', 'canyon', 'driftwood',
    'ostrich', 'pebble', 'quarry', 'ridge', 'sapling', 'timber', 'urgent', 'vapor', 'wharf', 'yield',
    'zesty', 'arrow', 'blossom', 'current', 'dune', 'ember',
    'frost', 'glacier', 'hollow', 'indigo', 'jigsaw', 'knight', 'lumber', 'mantle', 'nimbus', 'opal',
    'prairie', 'quartz', 'rustic', 'silver', 'thicket', 'umber',
    'vessel', 'whisper', 'yonder', 'zircon', 'alpine', 'boulder', 'coral', 'dusk', 'echo', 'flint',
    'grove', 'honey', 'ink', 'jade', 'karma', 'lilac',
    'marsh', 'north', 'oyster', 'plume', 'quill', 'ravine', 'south', 'tundra', 'umbra', 'vine',
    'wisdom', 'yak', 'zeal', 'ash', 'birch', 'cedar',
    'cliff', 'dawn', 'elm', 'fern', 'glade', 'hazel', 'ivy', 'juniper', 'knoll', 'linen',
    'moss', 'nest', 'oak', 'pine', 'quiver', 'reed',
    'spruce', 'thistle', 'urn', 'wren', 'yew', 'zest', 'bamboo', 'coconut', 'date', 'fig',
    'grape', 'kiwi', 'lemon', 'mango', 'olive', 'peach',
    'pear', 'plum', 'quince', 'raisin', 'cherry', 'melon', 'papaya', 'guava', 'lime', 'orange',
    'banana', 'berry', 'citrus', 'apricot', 'nutmeg', 'clove',
    'ginger', 'basil', 'thyme', 'mint', 'sage', 'dill', 'chive', 'parsley', 'oregano', 'rosemary',
    'paprika', 'turmeric', 'vanilla', 'cocoa', 'coffee', 'tea',
    'sugar', 'salt', 'flour', 'butter', 'cream', 'cheese', 'bread', 'toast', 'waffle', 'pancake',
    'syrup', 'jam', 'jelly', 'custard', 'pudding', 'biscuit',
    'cookie', 'cracker', 'pretzel', 'popcorn', 'cereal', 'oatmeal', 'granola', 'noodle', 'dumpling', 'sausage',
    'bacon', 'egg', 'milk', 'juice', 'soda', 'lemonade',
    'mountain', 'hill', 'plateau', 'plain', 'coast', 'shore', 'beach', 'cave', 'cavern', 'crater',
    'volcano', 'geyser', 'spring', 'brook', 'stream', 'waterfall',
  ];

  static final _secureRandom = Random.secure();

  /// Generates a passphrase of [wordCount] words (default 6, ~48 bits
  /// of entropy from the wordlist alone). Combined with
  /// [VaultCrypto.argon2idExport]'s memory-hard cost, this is meant
  /// for a short-lived, out-of-band-authenticated handoff — not for
  /// protecting something that must resist a well-resourced attacker
  /// indefinitely.
  static String generate({int wordCount = 6}) {
    return List.generate(wordCount, (_) => words[_secureRandom.nextInt(words.length)]).join('-');
  }

  /// A single random word from the list — used as a codename for a
  /// sealed export (e.g. its suggested filename) so the file's own
  /// name never gives away which vault it came from. Not a secret;
  /// just an anti-correlation label.
  static String generateCodename() => words[_secureRandom.nextInt(words.length)];

  /// Generates a numeric PIN of [digits] digits (default 6, ~20 bits
  /// of entropy — meaningfully less than [generate]'s word-based
  /// output). Offered as an option because it matches the app's own
  /// daily-unlock PIN, but unlike that PIN, a sealed export has no
  /// lockout to protect it once it leaves the device — there's nothing
  /// running to notice repeated wrong guesses against a file sitting
  /// in someone's inbox. Reasonable for a short-lived, trusted handoff;
  /// not for something that must stay safe indefinitely if the file
  /// leaks.
  static String generatePin({int digits = 6}) {
    return List.generate(digits, (_) => _secureRandom.nextInt(10)).join();
  }
}
