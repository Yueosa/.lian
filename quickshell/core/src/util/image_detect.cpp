#include "image_detect.h"

#include <QRegularExpression>
#include <QUrl>

namespace clavis::util {

QString detectImageKind(const QByteArray& d) {
    if (d.isEmpty()) return {};
    const auto sz = d.size();

    if (sz >= 8 && d.startsWith("\x89PNG\r\n\x1a\n")) return QStringLiteral("png");
    if (sz >= 3 && d.startsWith("\xff\xd8\xff")) return QStringLiteral("jpeg");
    if (sz >= 6 && (d.startsWith("GIF87a") || d.startsWith("GIF89a"))) return QStringLiteral("gif");
    if (sz >= 12 && d.startsWith("RIFF") && d.mid(8, 4) == "WEBP") return QStringLiteral("webp");
    if (sz >= 2 && d.startsWith("BM")) return QStringLiteral("bmp");
    if (sz >= 4 && (d.startsWith(QByteArray("II*\x00", 4)) || d.startsWith(QByteArray("MM\x00*", 4))))
        return QStringLiteral("tiff");
    if (sz >= 4 && d.startsWith(QByteArray("\x00\x00\x01\x00", 4))) return QStringLiteral("ico");

    if (sz >= 12 && d.mid(4, 4) == "ftyp") {
        const QByteArray brand = d.mid(8, 4);
        if (brand == "avif" || brand == "avis") return QStringLiteral("avif");
        if (brand == "heic" || brand == "heix" || brand == "hevc"
            || brand == "hevx" || brand == "mif1") return QStringLiteral("heic");
    }
    return {};
}

QString hintImageKind(const QString& previewLine) {
    if (previewLine.isEmpty()) return {};
    static const QRegularExpression re(
        QStringLiteral(R"(\[\[\s*binary data\s+[^\]]*?\b(png|jpe?g|gif|webp|bmp|tiff?|ico|avif|heic|heif)\b[^\]]*\]\])"),
        QRegularExpression::CaseInsensitiveOption);
    auto m = re.match(previewLine);
    if (!m.hasMatch()) return {};
    QString k = m.captured(1).toLower();
    if (k == QLatin1String("jpg")) k = QStringLiteral("jpeg");
    if (k == QLatin1String("tif")) k = QStringLiteral("tiff");
    if (k == QLatin1String("heif")) k = QStringLiteral("heic");
    return k;
}

bool looksBinary(const QByteArray& data) {
    if (data.isEmpty()) return false;
    const QByteArray sample = data.left(4096);
    if (sample.contains('\0')) return true;
    auto dec = QStringDecoder(QStringDecoder::Utf8, QStringDecoder::Flag::Stateless);
    QString s = dec.decode(sample);
    return dec.hasError();
}

QString extractHtmlImagePath(const QString& s) {
    if (s.isEmpty()) return {};
    QString head = s.trimmed().left(32).toLower();
    if (!(head.startsWith(QLatin1String("<html"))
          || head.startsWith(QLatin1String("<body"))
          || head.startsWith(QLatin1String("<img"))
          || head.startsWith(QLatin1String("<!doctype")))) return {};

    static const QRegularExpression re(
        QStringLiteral(R"(<img\b[^>]*?\bsrc\s*=\s*(["'])(.*?)\1)"),
        QRegularExpression::CaseInsensitiveOption | QRegularExpression::DotMatchesEverythingOption);
    auto m = re.match(s);
    if (!m.hasMatch()) return {};
    QString src = m.captured(2).trimmed();
    // unescape minimal HTML entities常见的几个
    src.replace(QLatin1String("&amp;"), QLatin1String("&"))
       .replace(QLatin1String("&quot;"), QLatin1String("\""))
       .replace(QLatin1String("&apos;"), QLatin1String("'"))
       .replace(QLatin1String("&lt;"), QLatin1String("<"))
       .replace(QLatin1String("&gt;"), QLatin1String(">"));
    if (src.startsWith(QLatin1String("file://"))) {
        return QUrl(src).toLocalFile();
    }
    if (src.startsWith(QLatin1Char('/'))) {
        return QUrl::fromPercentEncoding(src.toUtf8());
    }
    return {};
}

QString stripHtmlToPlain(const QString& html) {
    static const QRegularExpression tag(QStringLiteral("<[^>]+>"));
    QString s = html;
    s.replace(tag, QStringLiteral(" "));
    s.replace(QLatin1String("&amp;"), QLatin1String("&"))
     .replace(QLatin1String("&quot;"), QLatin1String("\""))
     .replace(QLatin1String("&apos;"), QLatin1String("'"))
     .replace(QLatin1String("&lt;"), QLatin1String("<"))
     .replace(QLatin1String("&gt;"), QLatin1String(">"))
     .replace(QLatin1String("&nbsp;"), QLatin1String(" "));
    static const QRegularExpression ws(QStringLiteral(R"(\s+)"));
    return s.replace(ws, QStringLiteral(" ")).trimmed();
}

QString extForKind(const QString& k) {
    if (k == QLatin1String("jpeg")) return QStringLiteral("jpg");
    return k;
}

} // namespace clavis::util
