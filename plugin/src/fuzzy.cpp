#include "fuzzy.hpp"

#include <algorithm>
#include <qregularexpression.h>
#include <qstringlist.h>
#include <vector>

namespace morph::search {

namespace {

// Initials only count once there are at least this many words: a single
// word's initial is just its first letter, which the word itself already
// covers.
constexpr qsizetype minAcronymLength = 2;

// Jaro-Winkler only rewards a shared start of up to this many letters.
constexpr qsizetype maxPrefix = 4;

const QRegularExpression& separators() {
    static const QRegularExpression re(QStringLiteral("[\\s\\-_]+"));
    return re;
}

} // namespace

Fuzzy::Fuzzy(QObject* parent)
    : QObject(parent) {}

qreal Fuzzy::jaro(const QString& a, const QString& b) {
    if (a == b)
        return 1.0;

    const qsizetype lenA = a.size();
    const qsizetype lenB = b.size();
    if (lenA == 0 || lenB == 0)
        return 0.0;

    // How far apart two equal letters may sit and still count as the
    // same letter. Never negative: for one-letter strings the usual
    // formula gives -1, which would rule out a match even in place.
    const qsizetype window = std::max<qsizetype>(0, std::max(lenA, lenB) / 2 - 1);

    std::vector<bool> matchedA(static_cast<size_t>(lenA), false);
    std::vector<bool> matchedB(static_cast<size_t>(lenB), false);

    qsizetype matches = 0;
    for (qsizetype i = 0; i < lenA; ++i) {
        const qsizetype from = std::max<qsizetype>(0, i - window);
        const qsizetype to = std::min(i + window + 1, lenB);

        for (qsizetype j = from; j < to; ++j) {
            if (matchedB[j] || a[i] != b[j])
                continue;
            matchedA[i] = true;
            matchedB[j] = true;
            ++matches;
            break;
        }
    }

    if (matches == 0)
        return 0.0;

    // Matched letters that come out in a different order in each string.
    qsizetype outOfOrder = 0;
    qsizetype k = 0;
    for (qsizetype i = 0; i < lenA; ++i) {
        if (!matchedA[i])
            continue;
        while (!matchedB[k])
            ++k;
        if (a[i] != b[k])
            ++outOfOrder;
        ++k;
    }

    const qreal m = static_cast<qreal>(matches);
    const qreal transpositions = static_cast<qreal>(outOfOrder) / 2.0;

    return (m / static_cast<qreal>(lenA) + m / static_cast<qreal>(lenB) + (m - transpositions) / m) / 3.0;
}

qreal Fuzzy::jaroWinkler(const QString& a, const QString& b, qreal prefixScale) {
    const qreal distance = jaro(a, b);

    const qsizetype limit = std::min({ maxPrefix, a.size(), b.size() });
    qsizetype prefix = 0;
    while (prefix < limit && a[prefix] == b[prefix])
        ++prefix;

    return distance + static_cast<qreal>(prefix) * prefixScale * (1.0 - distance);
}

qreal Fuzzy::score(const QString& query, const QString& text) {
    const QString q = query.toLower();
    const QString t = text.toLower();

    if (q.isEmpty() || t.isEmpty())
        return 0.0;

    const QStringList words = t.split(separators(), Qt::SkipEmptyParts);

    // Anywhere whole in the text with its separators gone -- "code" in
    // "visualstudiocode", or "viscode" across the words -- is as good as
    // it gets. The query loses its separators too, so "visual studio"
    // finds it the same way.
    const QString squished = words.join(QString());
    const QString bare = QString(q).remove(separators());
    if (bare.isEmpty())
        return 0.0;
    if (squished.contains(bare))
        return 1.0;

    qreal best = jaroWinkler(q, t);

    if (words.size() >= minAcronymLength) {
        QString acronym;
        acronym.reserve(words.size());
        for (const auto& word : words)
            acronym += word.front();
        best = std::max(best, jaroWinkler(q, acronym));
    }

    for (const auto& word : words)
        best = std::max(best, jaroWinkler(q, word));

    return best;
}

} // namespace morph::search
