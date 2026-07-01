class UserProfile {
  const UserProfile({
    required this.name,
    required this.bloodGroup,
    required this.phone,
    required this.relativeName,
    required this.relativePhone,
    required this.address,
  });

  final String name;
  final String bloodGroup;
  final String phone;
  final String relativeName;
  final String relativePhone;
  final String address;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'bloodGroup': bloodGroup,
      'phone': phone,
      'relativeName': relativeName,
      'relativePhone': relativePhone,
      'address': address,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name'] ?? '',
      bloodGroup: json['bloodGroup'] ?? '',
      phone: json['phone'] ?? '',
      relativeName: json['relativeName'] ?? '',
      relativePhone: json['relativePhone'] ?? '',
      address: json['address'] ?? '',
    );
  }

  bool get hasUsefulData {
    return name.trim().isNotEmpty ||
        phone.trim().isNotEmpty ||
        bloodGroup.trim().isNotEmpty ||
        relativeName.trim().isNotEmpty ||
        relativePhone.trim().isNotEmpty ||
        address.trim().isNotEmpty;
  }
}