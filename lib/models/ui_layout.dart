enum DailyLayout { classic, letter, reverie, noir, messenger }

// noir remains a persisted legacy alias, never a separate picker entry.
const selectableDailyLayouts = [DailyLayout.classic, DailyLayout.letter,
  DailyLayout.reverie, DailyLayout.messenger];
DailyLayout canonicalDailyLayout(DailyLayout value) =>
    value == DailyLayout.noir ? DailyLayout.reverie : value;

enum DreamLayout { classic, moonlit }

T decodeLayout<T extends Enum>(Object? value, List<T> choices, T fallback) =>
    choices.where((item) => item.name == value).firstOrNull ?? fallback;
