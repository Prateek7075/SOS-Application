class EmergencyContact {
  const EmergencyContact({
    this.id,
    required this.name,
    required this.phone,
    required this.relationship,
  });

  final int? id;
  final String name;
  final String phone;
  final String relationship;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'relationship': relationship,
    };
  }

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      id: json['id'],
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      relationship: json['relationship'] ?? 'Trusted Contact',
    );
  }
}