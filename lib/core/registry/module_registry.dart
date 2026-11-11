import 'package:flutter/material.dart';

/// Identifier untuk modul platform ESAS.
class EsasModules {
  const EsasModules._();

  static const String hrms = 'hrms';
  static const String gams = 'gams';
  static const String itms = 'itms';
  static const String mtms = 'mtms';

  /// Modul default yang selalu aktif di semua tenant.
  static const List<String> defaults = [hrms];

  /// Nama manusiawi untuk modul.
  static String labelOf(String module) {
    return switch (module.toLowerCase()) {
      hrms => 'Human Resources (HRMS)',
      gams => 'General Affairs (GAMS)',
      itms => 'IT Services (ITMS)',
      mtms => 'Maintenance (MTMS)',
      _ => module.toUpperCase(),
    };
  }
}

/// Definisi layanan self-service enterprise yang terdaftar dalam aplikasi.
class EnterpriseServiceItem {
  const EnterpriseServiceItem({
    required this.id,
    required this.module,
    required this.title,
    required this.description,
    required this.icon,
    required this.route,
    this.requiresApprovalRole = false,
    this.accent = false,
  });

  final String id;
  final String module;
  final String title;
  final String description;
  final IconData icon;
  final String route;
  final bool requiresApprovalRole;
  final bool accent;
}

/// Registry sentral untuk penemuan layanan mobile self-service secara dinamis
/// berdasarkan module entitlement tenant dan otorisasi pengguna.
class ModuleRegistry {
  const ModuleRegistry._();

  /// Semua layanan yang didukung platform mobile ESAS.
  static const List<EnterpriseServiceItem> allServices = [
    // ── HRMS Services ──
    EnterpriseServiceItem(
      id: 'hrms_attendance',
      module: EsasModules.hrms,
      title: 'Absensi',
      description: 'Catat kehadiran masuk dan pulang',
      icon: Icons.qr_code_scanner_rounded,
      route: '/attendance',
    ),
    EnterpriseServiceItem(
      id: 'hrms_permit_create',
      module: EsasModules.hrms,
      title: 'Ajukan Izin',
      description: 'Pengajuan cuti, izin, sakit, dan dinas',
      icon: Icons.post_add_rounded,
      route: '/permit',
    ),
    EnterpriseServiceItem(
      id: 'hrms_permit_list',
      module: EsasModules.hrms,
      title: 'Pengajuan',
      description: 'Daftar dan status permohonan izin/cuti',
      icon: Icons.fact_check_outlined,
      route: '/permit-list',
    ),
    EnterpriseServiceItem(
      id: 'hrms_attendance_history',
      module: EsasModules.hrms,
      title: 'Riwayat',
      description: 'Log presensi dan ketepatan waktu bulanan',
      icon: Icons.receipt_long_outlined,
      route: '/attendance/list',
    ),
    EnterpriseServiceItem(
      id: 'hrms_schedule',
      module: EsasModules.hrms,
      title: 'Jadwal Shift',
      description: 'Kalender jadwal kerja dan hari libur',
      icon: Icons.calendar_month_outlined,
      route: '/schedule',
    ),
    EnterpriseServiceItem(
      id: 'hrms_overtime',
      module: EsasModules.hrms,
      title: 'Lembur',
      description: 'Riwayat surat tugas dan jam kerja lembur',
      icon: Icons.more_time_rounded,
      route: '/overtime',
    ),
    EnterpriseServiceItem(
      id: 'hrms_financial',
      module: EsasModules.hrms,
      title: 'Pinjaman',
      description: 'Informasi sisa pinjaman & kasbon karyawan',
      icon: Icons.account_balance_wallet_outlined,
      route: '/profile/financial',
    ),
    EnterpriseServiceItem(
      id: 'hrms_ai_chat',
      module: EsasModules.hrms,
      title: 'AI Copilot',
      description: 'Asisten cerdas tanya jawab kebijakan & data',
      icon: Icons.auto_awesome_rounded,
      route: '/ai/chat',
    ),

    // ── GAMS Services (General Affairs & Facilities) ──
    EnterpriseServiceItem(
      id: 'gams_service_request',
      module: EsasModules.gams,
      title: 'Layanan GA',
      description: 'Permintaan perbaikan fasilitas dan logistik',
      icon: Icons.home_repair_service_outlined,
      route: '/gams/service-requests',
    ),
    EnterpriseServiceItem(
      id: 'gams_space_reservation',
      module: EsasModules.gams,
      title: 'Ruang Rapat',
      description: 'Pemesanan ruang pertemuan dan fasilitas',
      icon: Icons.meeting_room_outlined,
      route: '/gams/space-reservations',
    ),
    EnterpriseServiceItem(
      id: 'gams_vehicle_booking',
      module: EsasModules.gams,
      title: 'Kendaraan',
      description: 'Peminjaman kendaraan operasional kantor',
      icon: Icons.directions_car_outlined,
      route: '/gams/vehicle-bookings',
    ),
    EnterpriseServiceItem(
      id: 'gams_visitor_pass',
      module: EsasModules.gams,
      title: 'Buku Tamu',
      description: 'Pendaftaran pengunjung dan QR pass tamu',
      icon: Icons.badge_outlined,
      route: '/gams/visitor-passes',
    ),

    // ── ITMS Services (IT Service Management) ──
    EnterpriseServiceItem(
      id: 'itms_tickets',
      module: EsasModules.itms,
      title: 'Tiket IT',
      description: 'Lapor kendala perangkat, jaringan, atau sistem',
      icon: Icons.confirmation_number_outlined,
      route: '/itms/tickets',
    ),
    EnterpriseServiceItem(
      id: 'itms_catalog',
      module: EsasModules.itms,
      title: 'Katalog IT',
      description: 'Permintaan lisensi software, akun, atau aset IT',
      icon: Icons.inventory_2_outlined,
      route: '/itms/catalog',
    ),
    EnterpriseServiceItem(
      id: 'itms_knowledge',
      module: EsasModules.itms,
      title: 'Bantuan IT',
      description: 'Panduan mandiri dan solusi kendala teknis',
      icon: Icons.menu_book_outlined,
      route: '/itms/knowledge',
    ),

    // ── MTMS Operational Services ──
    EnterpriseServiceItem(
      id: 'mtms_work_orders',
      module: EsasModules.mtms,
      title: 'Perawatan',
      description: 'Laporan perbaikan mesin dan work order teknis',
      icon: Icons.build_circle_outlined,
      route: '/mtms/work-orders',
    ),

    // ── Cross-Panel Unified Approval Inbox ──
    EnterpriseServiceItem(
      id: 'unified_inbox',
      module: EsasModules.hrms,
      title: 'Persetujuan',
      description: 'Kotak masuk approval lintas panel (Cuti, GA, IT)',
      icon: Icons.approval_rounded,
      route: '/inbox/approvals',
      requiresApprovalRole: true,
    ),
  ];

  /// Mengembalikan daftar layanan yang aktif sesuai daftar modul tenant
  /// dan otorisasi pengguna.
  static List<EnterpriseServiceItem> getAvailableServices({
    required List<String> activeModules,
    bool isManager = false,
  }) {
    final normalized = activeModules.map((m) => m.toLowerCase().trim()).toSet();
    // HRMS selalu aktif sebagai platform baseline
    normalized.add(EsasModules.hrms);

    return allServices.where((service) {
      if (!normalized.contains(service.module.toLowerCase())) {
        return false;
      }
      if (service.requiresApprovalRole && !isManager) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Mengembalikan layanan yang dikelompokkan per modul aktif.
  static Map<String, List<EnterpriseServiceItem>> getServicesGroupedByModule({
    required List<String> activeModules,
    bool isManager = false,
  }) {
    final available = getAvailableServices(
      activeModules: activeModules,
      isManager: isManager,
    );

    final Map<String, List<EnterpriseServiceItem>> grouped = {};
    for (final service in available) {
      grouped.putIfAbsent(service.module, () => []).add(service);
    }
    return grouped;
  }
}

