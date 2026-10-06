#include "pixelsampler.hpp"

#include <qquickitemgrabresult.h>

namespace morph::components {

PixelSampler::PixelSampler(QObject* parent)
    : QObject(parent) {}

bool PixelSampler::ready() const {
    return !m_image.isNull();
}

QSize PixelSampler::size() const {
    return m_image.size();
}

void PixelSampler::load(QObject* grabResult, QSize size) {
    const auto* result = qobject_cast<QQuickItemGrabResult*>(grabResult);
    if (!result)
        return;

    // One known format, so colorAt() is a plain read whatever the
    // capture came in as. The screen has no transparency to keep.
    QImage image = result->image().convertToFormat(QImage::Format_RGB32);
    if (size.isValid() && image.size() != size)
        image = image.scaled(size, Qt::IgnoreAspectRatio, Qt::FastTransformation);

    m_image = std::move(image);
    emit imageChanged();
}

void PixelSampler::clear() {
    if (m_image.isNull())
        return;
    m_image = QImage();
    emit imageChanged();
}

QColor PixelSampler::colorAt(int x, int y) const {
    if (!m_image.valid(x, y))
        return Qt::transparent;
    return QColor::fromRgb(m_image.pixel(x, y));
}

const QImage& PixelSampler::image() const {
    return m_image;
}

} // namespace morph::components
