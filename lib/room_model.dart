class Room {
  final int id;
  final String name;
  final String description;
  final double price;
  final int bedrooms;
  final int bathrooms;
  final DateTime createdAt;

  Room({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.bedrooms,
    required this.bathrooms,
    required this.createdAt,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'No Name',
      description: json['description'] ?? '', // Handle null description
      price: (json['price'] ?? 0).toDouble(),
      bedrooms: json['bedrooms'] ?? 0,
      bathrooms: json['bathrooms'] ?? 0,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'bedrooms': bedrooms,
      'bathrooms': bathrooms,
      'created_at': createdAt.toIso8601String(),
    };
  }
}