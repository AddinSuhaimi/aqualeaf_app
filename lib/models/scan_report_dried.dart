class ScanReportDried {
  final int? scanId;
  final int farmId;
  final int speciesId;
  final String timestamp;
  final String imageUrl;
  final double impurityStatus;
  final String appearance;
  final String qualityStatus;
  final int synced;

  ScanReportDried({
    this.scanId,
    required this.farmId,
    required this.speciesId,
    required this.timestamp,
    required this.imageUrl,
    required this.impurityStatus,
    required this.appearance,
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
      'appearance': appearance,
      'quality_status': qualityStatus,
      'synced': synced,
    };
  }

  factory ScanReportDried.fromMap(Map<String, dynamic> map) {
    return ScanReportDried(
      scanId: map['scan_id'],
      farmId: map['farm_id'],
      speciesId: map['species_id'],
      timestamp: map['timestamp'],
      imageUrl: map['image_url'],
      impurityStatus: map['impurity_status'],
      appearance: map['appearance'],
      qualityStatus: map['quality_status'],
      synced: map['synced'],
    );
  }
}
