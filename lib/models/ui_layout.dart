enum DailyLayout { classic, letter, reverie, noir, messenger }

enum DreamLayout { classic, moonlit }

T decodeLayout<T extends Enum>(Object? value, List<T> choices, T fallback) =>
    choices.where((item) => item.name == value).firstOrNull ?? fallback;
