#pragma once

#include <qobject.h>
#include <qqmlintegration.h>

namespace morph::search {

// Typo-tolerant string similarity for the launcher, from 0 (nothing in
// common) to 1 (a match). Built on Jaro-Winkler, which forgives letters
// swapped, dropped or mistyped and favours a shared start, so
// "firefix" still finds Firefox. A query is held up against the whole
// text, each of its words and its initials, and counts as a full match
// wherever it appears whole, so "code", "vsc" and "viscode" all find
// Visual Studio Code.
class Fuzzy : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit Fuzzy(QObject* parent = nullptr);

    // Both arguments are compared as given; score() is the one that
    // folds case.
    Q_INVOKABLE [[nodiscard]] static qreal jaro(const QString& a, const QString& b);
    Q_INVOKABLE [[nodiscard]] static qreal jaroWinkler(const QString& a, const QString& b, qreal prefixScale = 0.1);

    // How well a query matches a text, case-insensitively.
    Q_INVOKABLE [[nodiscard]] static qreal score(const QString& query, const QString& text);
};

} // namespace morph::search
