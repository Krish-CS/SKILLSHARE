import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Lightweight XLSX image extractor.
///
/// Extracts embedded drawing images anchored to worksheet rows (top-left anchor).
/// Returned map key is zero-based worksheet row index.
class XlsxEmbeddedImageParser {
  static Map<int, Uint8List> extractFirstSheetRowImages(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes, verify: false);
      final files = <String, ArchiveFile>{
        for (final file in archive.files) file.name: file,
      };

      const workbookPath = 'xl/workbook.xml';
      const workbookRelsPath = 'xl/_rels/workbook.xml.rels';
      final workbookDoc = _readXml(files, workbookPath);
      final workbookRelsDoc = _readXml(files, workbookRelsPath);
      if (workbookDoc == null || workbookRelsDoc == null) {
        return const {};
      }

      final firstSheetElement = workbookDoc
          .findAllElements('sheet')
          .cast<XmlElement?>()
          .firstWhere((e) => e != null, orElse: () => null);
      if (firstSheetElement == null) return const {};

      final workbookSheetRid = _attrByLocalName(firstSheetElement, 'id');
      if (workbookSheetRid == null || workbookSheetRid.isEmpty) {
        return const {};
      }

      final sheetTarget = _resolveRelTargetById(
        relsDoc: workbookRelsDoc,
        relId: workbookSheetRid,
      );
      if (sheetTarget == null || sheetTarget.isEmpty) {
        return const {};
      }

      final worksheetPath = _resolveZipPath(workbookPath, sheetTarget);
      final worksheetDoc = _readXml(files, worksheetPath);
      if (worksheetDoc == null) return const {};

      final drawingElement = worksheetDoc
          .descendants
          .whereType<XmlElement>()
          .firstWhere((e) => e.name.local == 'drawing', orElse: () => XmlElement(XmlName('')));
      if (drawingElement.name.local.isEmpty) {
        return const {};
      }

      final drawingRid = _attrByLocalName(drawingElement, 'id');
      if (drawingRid == null || drawingRid.isEmpty) {
        return const {};
      }

      final worksheetRelsPath = _relsPathForPart(worksheetPath);
      final worksheetRelsDoc = _readXml(files, worksheetRelsPath);
      if (worksheetRelsDoc == null) return const {};

      final drawingTarget = _resolveRelTargetById(
        relsDoc: worksheetRelsDoc,
        relId: drawingRid,
      );
      if (drawingTarget == null || drawingTarget.isEmpty) {
        return const {};
      }

      final drawingPath = _resolveZipPath(worksheetPath, drawingTarget);
      final drawingDoc = _readXml(files, drawingPath);
      if (drawingDoc == null) return const {};

      final drawingRelsPath = _relsPathForPart(drawingPath);
      final drawingRelsDoc = _readXml(files, drawingRelsPath);
      if (drawingRelsDoc == null) return const {};

      final rowImages = <int, Uint8List>{};

      final anchors = drawingDoc.descendants.whereType<XmlElement>().where(
            (e) => e.name.local == 'oneCellAnchor' || e.name.local == 'twoCellAnchor',
          );

      for (final anchor in anchors) {
        final fromElement = anchor.children
            .whereType<XmlElement>()
            .firstWhere((e) => e.name.local == 'from', orElse: () => XmlElement(XmlName('')));
        if (fromElement.name.local.isEmpty) continue;

        final rowElement = fromElement.children
            .whereType<XmlElement>()
            .firstWhere((e) => e.name.local == 'row', orElse: () => XmlElement(XmlName('')));
        if (rowElement.name.local.isEmpty) continue;

        final rowIndex = int.tryParse(rowElement.innerText.trim());
        if (rowIndex == null || rowIndex < 0) continue;

        final blip = anchor
            .descendants
            .whereType<XmlElement>()
            .firstWhere((e) => e.name.local == 'blip', orElse: () => XmlElement(XmlName('')));
        if (blip.name.local.isEmpty) continue;

        final embedRid = _attrByLocalName(blip, 'embed');
        if (embedRid == null || embedRid.isEmpty) continue;

        final imageTarget = _resolveRelTargetById(
          relsDoc: drawingRelsDoc,
          relId: embedRid,
        );
        if (imageTarget == null || imageTarget.isEmpty) continue;

        final imagePath = _resolveZipPath(drawingPath, imageTarget);
        final imageFile = files[imagePath];
        if (imageFile == null || imageFile.isFile == false) continue;

        if (!rowImages.containsKey(rowIndex)) {
          rowImages[rowIndex] = Uint8List.fromList(imageFile.content as List<int>);
        }
      }

      return rowImages;
    } catch (_) {
      // Best-effort parser by design. Caller handles empty map fallback.
      return const {};
    }
  }

  static XmlDocument? _readXml(Map<String, ArchiveFile> files, String path) {
    final file = files[path];
    if (file == null || file.isFile == false) return null;
    final content = file.content;
    if (content is! List<int>) return null;
    final text = String.fromCharCodes(content);
    return XmlDocument.parse(text);
  }

  static String? _resolveRelTargetById({
    required XmlDocument relsDoc,
    required String relId,
  }) {
    for (final rel in relsDoc.descendants.whereType<XmlElement>()) {
      if (rel.name.local != 'Relationship') continue;
      final id = rel.getAttribute('Id');
      if (id == relId) {
        return rel.getAttribute('Target');
      }
    }
    return null;
  }

  static String? _attrByLocalName(XmlElement element, String localName) {
    for (final attr in element.attributes) {
      if (attr.name.local == localName) {
        return attr.value;
      }
    }
    return null;
  }

  static String _relsPathForPart(String partPath) {
    final slash = partPath.lastIndexOf('/');
    final dir = slash == -1 ? '' : partPath.substring(0, slash);
    final fileName = slash == -1 ? partPath : partPath.substring(slash + 1);
    return dir.isEmpty ? '_rels/$fileName.rels' : '$dir/_rels/$fileName.rels';
  }

  static String _resolveZipPath(String sourceFilePath, String target) {
    if (target.startsWith('/')) {
      return target.substring(1);
    }

    final sourceParts = sourceFilePath.split('/');
    if (sourceParts.isNotEmpty) {
      sourceParts.removeLast();
    }

    final targetParts = target.split('/');
    for (final part in targetParts) {
      if (part.isEmpty || part == '.') continue;
      if (part == '..') {
        if (sourceParts.isNotEmpty) {
          sourceParts.removeLast();
        }
      } else {
        sourceParts.add(part);
      }
    }

    return sourceParts.join('/');
  }
}
