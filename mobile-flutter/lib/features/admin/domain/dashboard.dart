/// Modelos espelhando os DTOs da Edu Admin API (Spring Boot, `api/`).
///
/// Substituem `analytics.dart`, que espelhava o `analytics-service` em
/// Python (não usado por este backend). Os nomes dos campos seguem os
/// DTOs Java em `api/src/main/java/com/edu/api/dashboard/dto/`,
/// `carrier/dto/` e `occurrence/dto/`.
library;

/// GET /dashboard
class DashboardResponse {
  const DashboardResponse({
    required this.educational,
    required this.operational,
    required this.executiveSummary,
  });

  factory DashboardResponse.fromJson(Map<String, dynamic> json) {
    return DashboardResponse(
      educational: EducationalMetrics.fromJson(
        json['educational'] as Map<String, dynamic>,
      ),
      operational: OperationalMetrics.fromJson(
        json['operational'] as Map<String, dynamic>,
      ),
      executiveSummary: json['executiveSummary'] as String? ?? '',
    );
  }

  final EducationalMetrics educational;
  final OperationalMetrics operational;
  final String executiveSummary;
}

/// Bloco `educational` de [DashboardResponse]
/// (`EducationalDashboardResponse.java`).
class EducationalMetrics {
  const EducationalMetrics({
    required this.registeredStudents,
    required this.activeStudents,
    required this.newRegistrations,
    required this.inactiveRiskStudents,
    required this.activityHistory,
  });

  factory EducationalMetrics.fromJson(Map<String, dynamic> json) {
    return EducationalMetrics(
      registeredStudents: _toInt(json['registeredStudents']),
      activeStudents: _toInt(json['activeStudents']),
      newRegistrations: _toInt(json['newRegistrations']),
      inactiveRiskStudents: _toInt(json['inactiveRiskStudents']),
      activityHistory: (json['activityHistory'] as List<dynamic>? ?? [])
          .map((e) => StudyActivity.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final int registeredStudents;
  final int activeStudents;
  final int newRegistrations;
  final int inactiveRiskStudents;
  final List<StudyActivity> activityHistory;
}

/// Bloco `operational` de [DashboardResponse]
/// (`OperationalDashboardResponse.java`).
class OperationalMetrics {
  const OperationalMetrics({
    required this.registeredProducts,
    required this.lowStockProducts,
    required this.activeCarriers,
    required this.openOccurrences,
    required this.lowStock,
    required this.carriers,
    required this.recentOccurrences,
  });

  factory OperationalMetrics.fromJson(Map<String, dynamic> json) {
    return OperationalMetrics(
      registeredProducts: _toInt(json['registeredProducts']),
      lowStockProducts: _toInt(json['lowStockProducts']),
      activeCarriers: _toInt(json['activeCarriers']),
      openOccurrences: _toInt(json['openOccurrences']),
      lowStock: (json['lowStock'] as List<dynamic>? ?? [])
          .map((e) => InventoryItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      carriers: (json['carriers'] as List<dynamic>? ?? [])
          .map((e) => Carrier.fromJson(e as Map<String, dynamic>))
          .toList(),
      recentOccurrences: (json['recentOccurrences'] as List<dynamic>? ?? [])
          .map((e) => CarrierOccurrence.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final int registeredProducts;
  final int lowStockProducts;
  final int activeCarriers;
  final int openOccurrences;
  final List<InventoryItem> lowStock;
  final List<Carrier> carriers;
  final List<CarrierOccurrence> recentOccurrences;
}

/// Um ponto do histórico de atividade educacional
/// (`StudyActivityResponse.java`), usado para o gráfico reduzido do
/// dashboard mobile.
class StudyActivity {
  const StudyActivity({
    required this.date,
    required this.studyActivities,
    required this.newRegistrations,
  });

  factory StudyActivity.fromJson(Map<String, dynamic> json) {
    return StudyActivity(
      date: json['date'] as String? ?? '',
      studyActivities: _toInt(json['studyActivities']),
      newRegistrations: _toInt(json['newRegistrations']),
    );
  }

  /// Data no formato `AAAA-MM-DD` (serialização padrão de `LocalDate`).
  final String date;
  final int studyActivities;
  final int newRegistrations;
}

/// Item de estoque baixo. Unifica os dois formatos devolvidos pela API:
/// `LowStockProductResponse` (embutido em `GET /dashboard`, campo
/// `currentQuantity`) e `InventoryResponse` (de `GET /inventory`, campo
/// `quantity`).
class InventoryItem {
  const InventoryItem({
    required this.productId,
    required this.productName,
    required this.sku,
    required this.quantity,
    required this.minimumStock,
    required this.status,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      productId: _toInt(json['productId']),
      productName: json['productName'] as String? ?? '',
      sku: json['sku'] as String? ?? '',
      quantity: _toInt(json['currentQuantity'] ?? json['quantity']),
      minimumStock: _toInt(json['minimumStock']),
      status: json['status'] as String? ?? 'NORMAL',
    );
  }

  final int productId;
  final String productName;
  final String sku;
  final int quantity;
  final int minimumStock;

  /// `NORMAL`, `LOW_STOCK` ou `OUT_OF_STOCK`.
  final String status;
}

/// Transportadora. Unifica os dois formatos devolvidos pela API:
/// `CarrierDashboardResponse` (embutido em `GET /dashboard`, campo
/// `carrierId`) e `CarrierResponse` (de `GET /carriers`, campo `id`, com
/// campos extras opcionais).
class Carrier {
  const Carrier({
    required this.id,
    required this.name,
    required this.rating,
    required this.slaPercentage,
    required this.averageDeliveryDays,
    this.location,
    this.email,
    this.status,
  });

  factory Carrier.fromJson(Map<String, dynamic> json) {
    return Carrier(
      id: _toInt(json['carrierId'] ?? json['id']),
      name: json['name'] as String? ?? '',
      rating: _toDouble(json['rating']),
      slaPercentage: _toDouble(json['slaPercentage']),
      averageDeliveryDays: _toInt(json['averageDeliveryDays']),
      location: json['location'] as String?,
      email: json['email'] as String?,
      status: json['status'] as String?,
    );
  }

  final int id;
  final String name;
  final double rating;
  final double slaPercentage;
  final int averageDeliveryDays;
  final String? location;
  final String? email;

  /// `ACTIVE` ou `INACTIVE` (só presente quando vindo de `GET /carriers`).
  final String? status;
}

/// Ocorrência de transportadora. Unifica os dois formatos devolvidos pela
/// API: `RecentOccurrenceResponse` (embutido em `GET /dashboard`, campo
/// `occurrenceId`) e `CarrierOccurrenceResponse` (de
/// `GET /carrier-occurrences`, campo `id`, com campos extras opcionais).
class CarrierOccurrence {
  const CarrierOccurrence({
    required this.id,
    required this.carrierName,
    required this.type,
    required this.status,
    required this.createdAt,
    this.carrierId,
    this.description,
    this.resolvedAt,
  });

  factory CarrierOccurrence.fromJson(Map<String, dynamic> json) {
    return CarrierOccurrence(
      id: _toInt(json['occurrenceId'] ?? json['id']),
      carrierId: json['carrierId'] != null ? _toInt(json['carrierId']) : null,
      carrierName: json['carrierName'] as String? ?? '',
      type: json['type'] as String? ?? 'OTHER',
      description: json['description'] as String?,
      status: json['status'] as String? ?? 'OPEN',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.tryParse(json['resolvedAt'] as String)
          : null,
    );
  }

  final int id;
  final int? carrierId;
  final String carrierName;

  /// `DELIVERY_DELAY`, `DAMAGE`, `DELIVERY_FAILURE` ou `OTHER`.
  final String type;
  final String? description;

  /// `OPEN` ou `RESOLVED`.
  final String status;
  final DateTime? createdAt;
  final DateTime? resolvedAt;
}

int _toInt(dynamic raw) {
  if (raw == null) return 0;
  return (raw as num).toInt();
}

double _toDouble(dynamic raw) {
  if (raw == null) return 0;
  return (raw as num).toDouble();
}
