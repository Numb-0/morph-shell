#pragma once

#include "pixelsampler.hpp"

#include <qcolor.h>
#include <qpointer.h>
#include <qqmlintegration.h>
#include <qquickpainteditem.h>

namespace morph::components {

// A round magnifier over a PixelSampler's image: a square of pixels
// around a centre one, each drawn as a flat cell with a fine grid
// between them and the centre outlined. Drawn from the image's own
// pixels rather than by scaling the view up, which would smear them at
// fractional scales.
class PixelLens : public QQuickPaintedItem {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(PixelSampler* sampler READ sampler WRITE setSampler NOTIFY samplerChanged FINAL)
    Q_PROPERTY(int centerX READ centerX WRITE setCenterX NOTIFY centerXChanged FINAL)
    Q_PROPERTY(int centerY READ centerY WRITE setCenterY NOTIFY centerYChanged FINAL)
    // Pixels across the lens. Rounded up to odd, so there is a middle one.
    Q_PROPERTY(int cells READ cells WRITE setCells NOTIFY cellsChanged FINAL)
    Q_PROPERTY(QColor gridColor READ gridColor WRITE setGridColor NOTIFY gridColorChanged FINAL)
    Q_PROPERTY(QColor markerColor READ markerColor WRITE setMarkerColor NOTIFY markerColorChanged FINAL)

public:
    explicit PixelLens(QQuickItem* parent = nullptr);

    [[nodiscard]] PixelSampler* sampler() const;
    void setSampler(PixelSampler* sampler);

    [[nodiscard]] int centerX() const;
    void setCenterX(int x);

    [[nodiscard]] int centerY() const;
    void setCenterY(int y);

    [[nodiscard]] int cells() const;
    void setCells(int cells);

    [[nodiscard]] QColor gridColor() const;
    void setGridColor(const QColor& color);

    [[nodiscard]] QColor markerColor() const;
    void setMarkerColor(const QColor& color);

    void paint(QPainter* painter) override;

signals:
    void samplerChanged();
    void centerXChanged();
    void centerYChanged();
    void cellsChanged();
    void gridColorChanged();
    void markerColorChanged();

private:
    QPointer<PixelSampler> m_sampler;
    QMetaObject::Connection m_samplerConnection;
    int m_centerX;
    int m_centerY;
    int m_cells;
    QColor m_gridColor;
    QColor m_markerColor;
};

} // namespace morph::components
