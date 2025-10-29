class ScanReport {
  final int? scanId;
  final String farmId;
  final String speciesId;
  final String timestamp;
  final String imageUrl;
  final double impurityLevel;
  final String discolorationStatus;
  final String qualityStatus;
  final int synced;

  ScanReport({
    this.scanId,
    required this.farmId,
    required this.speciesId,
    required this.timestamp,
    required this.imageUrl,
    required this.impurityLevel,
    required this.discolorationStatus,
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
      'impurity_level': impurityLevel,
      'discoloration_status': discolorationStatus,
      'quality_status': qualityStatus,
      'synced': synced,
    };
  }

  factory ScanReport.fromMap(Map<String, dynamic> map) {
    return ScanReport(
      scanId: map['scan_id'],
      farmId: map['farm_id'],
      speciesId: map['species_id'],
      timestamp: map['timestamp'],
      imageUrl: map['image_url'],
      impurityLevel: map['impurity_level'],
      discolorationStatus: map['discoloration_status'],
      qualityStatus: map['quality_status'],
      synced: map['synced'],
    );
  }
}
