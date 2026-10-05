import 'dart:convert';
import 'dart:typed_data';

import '../../../../core/utils/json_parsers.dart';
import '../../../../core/network/api_exception.dart';
import '../models/payslip.dart';
import '../services/profile_api_service.dart';

class PayrollRepository {
  const PayrollRepository(this._api);
  final ProfileApiService _api;
  Future<PayslipPage> page({int page = 1}) async {
    try {
      return PayslipPage.fromJson(await _api.payslips(page: page));
    } on FormatException {
      throw const ApiException(
        'Data slip gaji tidak valid. Silakan coba lagi.',
      );
    }
  }

  Future<Payslip> slip(int id) async {
    try {
      return Payslip.fromJson(asObject((await _api.payslip(id))['slip']));
    } on FormatException {
      throw const ApiException(
        'Data slip gaji tidak valid. Silakan coba lagi.',
      );
    }
  }

  Future<({String filename, Uint8List bytes})> pdf(int id) async {
    final response = await _api.payslipPdf(id);
    final bytes = base64Decode(asString(response['content_base64']) ?? '');
    if (bytes.length < 5 || utf8.decode(bytes.take(5).toList()) != '%PDF-') {
      throw const FormatException('Invalid payslip PDF');
    }
    return (filename: 'slip-gaji-$id.pdf', bytes: bytes);
  }
}
