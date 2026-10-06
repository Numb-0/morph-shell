#pragma once

#include <qcolor.h>
#include <qimage.h>
#include <qobject.h>
#include <qqmlintegration.h>

namespace morph::components {

// Holds a still of the screen so its pixels can be read from QML, which
// has no way of its own to ask a ScreencopyView what colour a point is.
// Loaded from a grabToImage() of the frozen view, made at the capture's
// own size so one pixel of the image is one pixel of the screen.
class PixelSampler : public QObject {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool ready READ ready NOTIFY imageChanged FINAL)
    Q_PROPERTY(QSize size READ size NOTIFY imageChanged FINAL)

public:
    explicit PixelSampler(QObject* parent = nullptr);

    [[nodiscard]] bool ready() const;
    [[nodiscard]] QSize size() const;

    // Takes the image out of an ItemGrabResult. A grab comes back
    // scaled by the window's device pixel ratio, which rounds; anything
    // off from size is brought to it pixel for pixel, never blended.
    Q_INVOKABLE void load(QObject* grabResult, QSize size);
    Q_INVOKABLE void clear();

    // In image pixels. Transparent outside the image.
    Q_INVOKABLE [[nodiscard]] QColor colorAt(int x, int y) const;

    [[nodiscard]] const QImage& image() const;

signals:
    void imageChanged();

private:
    QImage m_image;
};

} // namespace morph::components
