#include "pixellens.hpp"

#include <qpainter.h>
#include <qpainterpath.h>

namespace morph::components {

PixelLens::PixelLens(QQuickItem* parent)
    : QQuickPaintedItem(parent)
    , m_centerX(0)
    , m_centerY(0)
    , m_cells(11)
    , m_gridColor(0, 0, 0, 40)
    , m_markerColor(Qt::white) {
    setAntialiasing(true);
}

PixelSampler* PixelLens::sampler() const {
    return m_sampler;
}

void PixelLens::setSampler(PixelSampler* sampler) {
    if (m_sampler == sampler)
        return;

    disconnect(m_samplerConnection);
    m_sampler = sampler;
    if (sampler)
        m_samplerConnection = connect(sampler, &PixelSampler::imageChanged, this, [this] {
            update();
        });

    emit samplerChanged();
    update();
}

int PixelLens::centerX() const {
    return m_centerX;
}

void PixelLens::setCenterX(int x) {
    if (m_centerX != x) {
        m_centerX = x;
        emit centerXChanged();
        update();
    }
}

int PixelLens::centerY() const {
    return m_centerY;
}

void PixelLens::setCenterY(int y) {
    if (m_centerY != y) {
        m_centerY = y;
        emit centerYChanged();
        update();
    }
}

int PixelLens::cells() const {
    return m_cells;
}

void PixelLens::setCells(int cells) {
    cells = std::max(1, cells) | 1;
    if (m_cells != cells) {
        m_cells = cells;
        emit cellsChanged();
        update();
    }
}

QColor PixelLens::gridColor() const {
    return m_gridColor;
}

void PixelLens::setGridColor(const QColor& color) {
    if (m_gridColor != color) {
        m_gridColor = color;
        emit gridColorChanged();
        update();
    }
}

QColor PixelLens::markerColor() const {
    return m_markerColor;
}

void PixelLens::setMarkerColor(const QColor& color) {
    if (m_markerColor != color) {
        m_markerColor = color;
        emit markerColorChanged();
        update();
    }
}

void PixelLens::paint(QPainter* painter) {
    if (!m_sampler || !m_sampler->ready())
        return;

    const QImage& image = m_sampler->image();
    const qreal side = std::min(width(), height());
    const qreal cell = side / m_cells;
    const int half = m_cells / 2;

    QPainterPath circle;
    circle.addEllipse(QRectF(0, 0, side, side));
    painter->setClipPath(circle);

    // Cells on whole-pixel edges, each starting where the last ended,
    // or a hairline of the background shows through every seam.
    const auto edge = [cell](int i) {
        return qRound(i * cell);
    };
    painter->setRenderHint(QPainter::Antialiasing, false);
    for (int row = 0; row < m_cells; ++row) {
        for (int col = 0; col < m_cells; ++col) {
            const int x = m_centerX - half + col;
            const int y = m_centerY - half + row;
            if (!image.valid(x, y))
                continue;

            painter->fillRect(QRect(QPoint(edge(col), edge(row)), QPoint(edge(col + 1) - 1, edge(row + 1) - 1)),
                QColor::fromRgb(image.pixel(x, y)));
        }
    }

    painter->setPen(QPen(m_gridColor, 1));
    for (int i = 1; i < m_cells; ++i) {
        const qreal p = i * cell;
        painter->drawLine(QPointF(p, 0), QPointF(p, side));
        painter->drawLine(QPointF(0, p), QPointF(side, p));
    }

    painter->setRenderHint(QPainter::Antialiasing, true);
    painter->setPen(QPen(m_markerColor, 2));
    painter->setBrush(Qt::NoBrush);
    painter->drawRect(QRectF(half * cell, half * cell, cell, cell));
}

} // namespace morph::components
