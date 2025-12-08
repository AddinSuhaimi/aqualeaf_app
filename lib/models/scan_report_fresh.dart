class ScanReportFresh {
  final int? scanId;
  final int farmId;
  final int speciesId;
  final String timestamp;
  final String imageUrl;
  final double impurityStatus;
  final String healthStatus;
  final String qualityStatus;
  final int synced;

  ScanReportFresh({
    this.scanId,
    required this.farmId,
    required this.speciesId,
    required this.timestamp,
    required this.imageUrl,
    required this.impurityStatus,
    required this.healthStatus,
    required this.qualityStatus,
    this.synced = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'scan_id': scanId,
      'farm_id': farmId,
      'species_id': speciesId,
      'timestamp': timestamp,
      'image_url': imageUrl,
      'impurity_status': impurityStatus,
      'health_status': healthStatus,
      'quality_status': qualityStatus,
      'synced': synced,
    };
  }

  Map<String, dynamic> toUploadMap() {
    final map = toMap();
    map.remove('scan_id');
    map.remove('synced');
    return map;
  }

  factory ScanReportFresh.fromMap(Map<String, dynamic> map) {
    return ScanReportFresh(
      scanId: map['scan_id'],
      farmId: map['farm_id'],
      speciesId: map['species_id'],
      timestamp: map['timestamp'],
      imageUrl: map['image_url'],
      impurityStatus: map['impurity_status'],
      healthStatus: map['health_status'],
      qualityStatus: map['quality_status'],
      synced: map['synced'] as int? ?? 0,
    );
  }
}
