import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;

import '../models/company_profile.dart';
import '../models/user_model.dart';
import 'cloudinary_service.dart';
import 'firestore_service.dart';

class OfferLetterService {
  OfferLetterService({
    FirestoreService? firestoreService,
    CloudinaryService? cloudinaryService,
  })  : _firestoreService = firestoreService ?? FirestoreService(),
        _cloudinaryService = cloudinaryService ?? CloudinaryService();

  final FirestoreService _firestoreService;
  final CloudinaryService _cloudinaryService;

  Future<String?> createAndUploadOfferLetterPdf({
    required String companyId,
    required String candidateName,
    required String position,
    required String compensation,
    String? location,
    String? joiningDate,
    String? additionalTerms,
  }) async {
    final companyUser = await _firestoreService.getUserById(companyId);
    final companyProfile = await _firestoreService.getCompanyProfile(companyId);
    final pdfBytes = await _buildPdfBytes(
      companyUser: companyUser,
      companyProfile: companyProfile,
      candidateName: candidateName,
      position: position,
      compensation: compensation,
      location: location,
      joiningDate: joiningDate,
      additionalTerms: additionalTerms,
    );

    final safePosition = position
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');

    return _cloudinaryService.uploadPdfBytes(
      pdfBytes,
      folder: 'offer_letters',
      filename:
          'offer_letter_${safePosition.isEmpty ? 'candidate' : safePosition}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  Future<Uint8List> _buildPdfBytes({
    required UserModel? companyUser,
    required CompanyProfile? companyProfile,
    required String candidateName,
    required String position,
    required String compensation,
    String? location,
    String? joiningDate,
    String? additionalTerms,
  }) async {
    final doc = pw.Document();
    final displayName = _companyDisplayName(companyUser, companyProfile);
    final officeAddress = _companyAddress(companyProfile);
    final logoBytes = await _loadLogoBytes(companyProfile?.logoUrl);
    final issueDate = DateFormat('dd MMMM yyyy').format(DateTime.now());

    doc.addPage(
      pw.MultiPage(
        pageTheme: const pw.PageTheme(
          margin: pw.EdgeInsets.fromLTRB(36, 42, 36, 42),
        ),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(24),
            decoration: pw.BoxDecoration(
              gradient: const pw.LinearGradient(
                colors: [
                  PdfColor.fromInt(0xFF1A237E),
                  PdfColor.fromInt(0xFF3949AB),
                  PdfColor.fromInt(0xFFE91E63),
                ],
                begin: pw.Alignment.topLeft,
                end: pw.Alignment.bottomRight,
              ),
              borderRadius: pw.BorderRadius.circular(20),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Container(
                  width: 58,
                  height: 58,
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(14),
                  ),
                  alignment: pw.Alignment.center,
                  child: logoBytes != null
                      ? pw.ClipRRect(
                          horizontalRadius: 14,
                          verticalRadius: 14,
                          child: pw.Image(
                            pw.MemoryImage(logoBytes),
                            fit: pw.BoxFit.cover,
                          ),
                        )
                      : pw.Text(
                          displayName.substring(0, 1).toUpperCase(),
                          style: pw.TextStyle(
                            fontSize: 28,
                            fontWeight: pw.FontWeight.bold,
                            color: const PdfColor.fromInt(0xFF1A237E),
                          ),
                        ),
                ),
                pw.SizedBox(width: 18),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        displayName,
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Official Offer Letter',
                        style: const pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 24),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _labelValue('Issued On', issueDate),
                    if (officeAddress.isNotEmpty) ...[
                      pw.SizedBox(height: 8),
                      _labelValue('Office', officeAddress),
                    ],
                    if ((companyProfile?.website ?? '').trim().isNotEmpty) ...[
                      pw.SizedBox(height: 8),
                      _labelValue('Website', companyProfile!.website!.trim()),
                    ],
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Text(
            'Dear ${candidateName.trim().isEmpty ? 'Candidate' : candidateName.trim()},',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFF1A237E),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'We are pleased to confirm your selection for the position of $position at $displayName. This document outlines the primary offer details. A final onboarding confirmation can be shared if any company-specific formalities remain.',
            style: const pw.TextStyle(
              fontSize: 12,
              lineSpacing: 4,
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Container(
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFFF5F7FF),
              borderRadius: pw.BorderRadius.circular(18),
              border: pw.Border.all(
                color: const PdfColor.fromInt(0xFFD6DCFF),
              ),
            ),
            padding: const pw.EdgeInsets.all(18),
            child: pw.Column(
              children: [
                _detailRow('Position', position),
                _detailRow('Compensation', compensation),
                if ((location ?? '').trim().isNotEmpty)
                  _detailRow('Work Location', location!.trim()),
                if ((joiningDate ?? '').trim().isNotEmpty)
                  _detailRow('Joining Date', joiningDate!.trim()),
              ],
            ),
          ),
          if ((additionalTerms ?? '').trim().isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text(
              'Additional Terms',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: const PdfColor.fromInt(0xFF263238),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              additionalTerms!.trim(),
              style: const pw.TextStyle(
                fontSize: 12,
                lineSpacing: 4,
              ),
            ),
          ],
          pw.SizedBox(height: 28),
          pw.Text(
            'Please retain this letter for your records. We look forward to welcoming you to the team.',
            style: const pw.TextStyle(
              fontSize: 12,
              lineSpacing: 4,
            ),
          ),
          pw.SizedBox(height: 28),
          pw.Text(
            'Regards,',
            style: const pw.TextStyle(fontSize: 12),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            displayName,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFF1A237E),
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }

  String _companyDisplayName(UserModel? companyUser, CompanyProfile? profile) {
    final profileName = (profile?.companyName ?? '').trim();
    if (profileName.isNotEmpty) return profileName;
    final userName = (companyUser?.name ?? '').trim();
    if (userName.isNotEmpty) return userName;
    return 'SkillShare Company';
  }

  String _companyAddress(CompanyProfile? profile) {
    final parts = [
      profile?.headOfficeLocation?.trim(),
      profile?.city?.trim(),
      profile?.state?.trim(),
    ]
        .where((value) => value != null && value.isNotEmpty)
        .cast<String>()
        .toList();
    return parts.join(', ');
  }

  Future<Uint8List?> _loadLogoBytes(String? logoUrl) async {
    final cleanedUrl = (logoUrl ?? '').trim();
    if (cleanedUrl.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(cleanedUrl));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response.bodyBytes;
        }
      } catch (_) {}
    }

    try {
      final data = await rootBundle.load('assets/icons/app_icon.png');
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  pw.Widget _labelValue(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(
            color: PdfColor.fromInt(0xFF6B7280),
            fontSize: 10,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: const PdfColor.fromInt(0xFF111827),
          ),
        ),
      ],
    );
  }

  pw.Widget _detailRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 110,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: const PdfColor.fromInt(0xFF3949AB),
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
