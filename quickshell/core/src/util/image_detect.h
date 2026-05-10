#pragma once

#include <QByteArray>
#include <QString>

namespace clavis::util {

// 返回小写格式 token：png|jpeg|gif|webp|bmp|tiff|ico|avif|heic；未知返回空。
// 端口自 scripts/clipboard_dump.py:detect_image_kind
QString detectImageKind(const QByteArray& data);

// 解析 cliphist list 行尾标注：[[ binary data N KiB <type> WxH ]]
QString hintImageKind(const QString& previewLine);

// 启发式：data 看起来像不可显示二进制时返回 true（NUL 字节 / utf-8 失败）
bool looksBinary(const QByteArray& data);

// 从 HTML 富文本中抽取首个 <img src="file:///..."/> 的本地路径；找不到返回空
QString extractHtmlImagePath(const QString& decodedText);

// 简单 HTML → 纯文本（去标签、unescape entity、合并空白）
QString stripHtmlToPlain(const QString& html);

// 给定 magic kind ("png"/"jpeg"/...) 推荐文件扩展名（jpeg→jpg）
QString extForKind(const QString& kind);

} // namespace clavis::util
