class AdminCategory {
  const AdminCategory({
    required this.id,
    required this.slug,
    required this.name,
    required this.sortOrder,
    required this.active,
    this.nameMy,
    this.iconUrl,
  });

  final int id;
  final String slug;
  final String name;
  final int sortOrder;
  final bool active;
  final String? nameMy;
  final String? iconUrl;

  factory AdminCategory.fromJson(Map<String, dynamic> json) => AdminCategory(
        id: (json['id'] as num).toInt(),
        slug: json['slug'] as String,
        name: json['name'] as String,
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
        active: json['active'] as bool? ?? true,
        nameMy: json['nameMy'] as String?,
        iconUrl: json['iconUrl'] as String?,
      );

  Map<String, dynamic> toRequestJson() => {
        'slug': slug,
        'name': name,
        'nameMy': nameMy,
        'iconUrl': iconUrl,
        'sortOrder': sortOrder,
        'active': active,
      };
}

class AdminProductField {
  const AdminProductField({
    required this.key,
    required this.label,
    required this.inputType,
    required this.required,
    this.id,
    this.labelMy,
    this.placeholder,
    this.helpText,
    this.options = const [],
    this.validationRegex,
    this.sortOrder = 0,
  });

  final String key;
  final String label;
  final String inputType;
  final bool required;
  final int? id;
  final String? labelMy;
  final String? placeholder;
  final String? helpText;
  final List<String> options;
  final String? validationRegex;
  final int sortOrder;

  factory AdminProductField.fromJson(Map<String, dynamic> json) =>
      AdminProductField(
        id: (json['id'] as num?)?.toInt(),
        key: json['key'] as String,
        label: json['label'] as String,
        inputType: json['inputType'] as String? ?? 'TEXT',
        required: json['required'] as bool? ?? true,
        labelMy: json['labelMy'] as String?,
        placeholder: json['placeholder'] as String?,
        helpText: json['helpText'] as String?,
        options:
            (json['options'] as List<dynamic>? ?? []).map((e) => '$e').toList(),
        validationRegex: json['validationRegex'] as String?,
      );

  Map<String, dynamic> toRequestJson() => {
        if (id != null) 'id': id,
        'key': key,
        'label': label,
        'labelMy': labelMy,
        'placeholder': placeholder,
        'helpText': helpText,
        'inputType': inputType,
        'options': options,
        'validationRegex': validationRegex,
        'required': required,
        'sortOrder': sortOrder,
      };
}

class AdminVariant {
  const AdminVariant({
    required this.id,
    required this.productId,
    required this.productName,
    required this.sku,
    required this.name,
    required this.price,
    required this.costPrice,
    required this.stockType,
    required this.stockQuantity,
    required this.availableCodes,
    required this.lowStockThreshold,
    required this.maxPerOrder,
    required this.popularity,
    required this.sortOrder,
    required this.active,
    this.nameMy,
    this.bonusText,
    this.description,
    this.compareAtPrice,
    this.imageUrl,
    this.supplier,
    this.supplierProductId,
  });

  final int id;
  final int productId;
  final String productName;
  final String sku;
  final String name;
  final int price;
  final int costPrice;
  final String stockType;
  final int stockQuantity;
  final int availableCodes;
  final int lowStockThreshold;
  final int maxPerOrder;
  final int popularity;
  final int sortOrder;
  final bool active;
  final String? nameMy;
  final String? bonusText;
  final String? description;
  final int? compareAtPrice;
  final String? imageUrl;
  final String? supplier;
  final String? supplierProductId;

  bool get isUnlimited => stockType == 'UNLIMITED';
  bool get isCodePool => stockType == 'CODE_POOL';

  /// What the shop actually has: codes for a pool, the counter otherwise.
  int get available => isCodePool ? availableCodes : stockQuantity;

  bool get isLowStock => !isUnlimited && available <= lowStockThreshold;

  int get margin => price - costPrice;

  factory AdminVariant.fromJson(Map<String, dynamic> json) => AdminVariant(
        id: (json['id'] as num).toInt(),
        productId: (json['productId'] as num).toInt(),
        productName: json['productName'] as String? ?? '',
        sku: json['sku'] as String,
        name: json['name'] as String,
        price: (json['price'] as num).toInt(),
        costPrice: (json['costPrice'] as num?)?.toInt() ?? 0,
        stockType: json['stockType'] as String? ?? 'UNLIMITED',
        stockQuantity: (json['stockQuantity'] as num?)?.toInt() ?? 0,
        availableCodes: (json['availableCodes'] as num?)?.toInt() ?? 0,
        lowStockThreshold: (json['lowStockThreshold'] as num?)?.toInt() ?? 5,
        maxPerOrder: (json['maxPerOrder'] as num?)?.toInt() ?? 10,
        popularity: (json['popularity'] as num?)?.toInt() ?? 0,
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
        active: json['active'] as bool? ?? true,
        nameMy: json['nameMy'] as String?,
        bonusText: json['bonusText'] as String?,
        description: json['description'] as String?,
        compareAtPrice: (json['compareAtPrice'] as num?)?.toInt(),
        imageUrl: json['imageUrl'] as String?,
        supplier: json['supplier'] as String?,
        supplierProductId: json['supplierProductId'] as String?,
      );
}

class AdminProduct {
  const AdminProduct({
    required this.id,
    required this.slug,
    required this.name,
    required this.fulfillmentType,
    required this.featured,
    required this.sortOrder,
    required this.active,
    required this.categoryId,
    required this.categoryName,
    required this.fields,
    required this.variants,
    this.nameMy,
    this.description,
    this.descriptionMy,
    this.imageUrl,
    this.bannerUrl,
    this.instructions,
    this.instructionsMy,
    this.supplierGame,
  });

  final int id;
  final String slug;
  final String name;
  final String fulfillmentType;
  final bool featured;
  final int sortOrder;
  final bool active;
  final int categoryId;
  final String categoryName;
  final List<AdminProductField> fields;
  final List<AdminVariant> variants;
  final String? nameMy;
  final String? description;
  final String? descriptionMy;
  final String? imageUrl;
  final String? bannerUrl;
  final String? instructions;
  final String? instructionsMy;
  final String? supplierGame;

  int get lowStockCount =>
      variants.where((v) => v.active && v.isLowStock).length;

  factory AdminProduct.fromJson(Map<String, dynamic> json) => AdminProduct(
        id: (json['id'] as num).toInt(),
        slug: json['slug'] as String,
        name: json['name'] as String,
        fulfillmentType: json['fulfillmentType'] as String? ?? 'MANUAL',
        featured: json['featured'] as bool? ?? false,
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
        active: json['active'] as bool? ?? true,
        categoryId: (json['categoryId'] as num).toInt(),
        categoryName: json['categoryName'] as String? ?? '',
        fields: (json['fields'] as List<dynamic>? ?? [])
            .map((e) => AdminProductField.fromJson(e as Map<String, dynamic>))
            .toList(),
        variants: (json['variants'] as List<dynamic>? ?? [])
            .map((e) => AdminVariant.fromJson(e as Map<String, dynamic>))
            .toList(),
        nameMy: json['nameMy'] as String?,
        description: json['description'] as String?,
        descriptionMy: json['descriptionMy'] as String?,
        imageUrl: json['imageUrl'] as String?,
        bannerUrl: json['bannerUrl'] as String?,
        instructions: json['instructions'] as String?,
        instructionsMy: json['instructionsMy'] as String?,
        supplierGame: json['supplierGame'] as String?,
      );
}

class StockMovement {
  const StockMovement({
    required this.id,
    required this.delta,
    required this.quantityBefore,
    required this.quantityAfter,
    required this.reason,
    required this.actor,
    required this.createdAt,
    this.note,
  });

  final int id;
  final int delta;
  final int quantityBefore;
  final int quantityAfter;
  final String reason;
  final String actor;
  final DateTime createdAt;
  final String? note;

  factory StockMovement.fromJson(Map<String, dynamic> json) => StockMovement(
        id: (json['id'] as num).toInt(),
        delta: (json['delta'] as num).toInt(),
        quantityBefore: (json['quantityBefore'] as num).toInt(),
        quantityAfter: (json['quantityAfter'] as num).toInt(),
        reason: json['reason'] as String? ?? '',
        actor: json['actor'] as String? ?? 'system',
        createdAt: DateTime.parse(json['createdAt'] as String),
        note: json['note'] as String?,
      );
}

class StockCode {
  const StockCode({
    required this.id,
    required this.codeMasked,
    required this.status,
    required this.createdAt,
    this.assignedAt,
  });

  final int id;
  final String codeMasked;
  final String status;
  final DateTime createdAt;
  final DateTime? assignedAt;

  factory StockCode.fromJson(Map<String, dynamic> json) => StockCode(
        id: (json['id'] as num).toInt(),
        codeMasked: json['codeMasked'] as String? ?? '••••',
        status: json['status'] as String? ?? 'AVAILABLE',
        createdAt: DateTime.parse(json['createdAt'] as String),
        assignedAt: json['assignedAt'] == null
            ? null
            : DateTime.parse(json['assignedAt'] as String),
      );
}

class AdminUser {
  const AdminUser({
    required this.id,
    required this.publicId,
    required this.email,
    required this.displayName,
    required this.role,
    required this.status,
    required this.balance,
    required this.totalSpent,
    required this.orderCount,
    required this.createdAt,
    this.phone,
    this.photoUrl,
    this.lastLoginAt,
  });

  final int id;
  final String publicId;
  final String email;
  final String displayName;
  final String role;
  final String status;
  final int balance;
  final int totalSpent;
  final int orderCount;
  final DateTime createdAt;
  final String? phone;
  final String? photoUrl;
  final DateTime? lastLoginAt;

  bool get isAdmin => role == 'ADMIN' || role == 'SUPER_ADMIN';
  bool get isSuspended => status == 'SUSPENDED';

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
        id: (json['id'] as num).toInt(),
        publicId: json['publicId'] as String? ?? '',
        email: json['email'] as String,
        displayName: json['displayName'] as String? ?? '',
        role: json['role'] as String? ?? 'USER',
        status: json['status'] as String? ?? 'ACTIVE',
        balance: (json['balance'] as num?)?.toInt() ?? 0,
        totalSpent: (json['totalSpent'] as num?)?.toInt() ?? 0,
        orderCount: (json['orderCount'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.parse(json['createdAt'] as String),
        phone: json['phone'] as String?,
        photoUrl: json['photoUrl'] as String?,
        lastLoginAt: json['lastLoginAt'] == null
            ? null
            : DateTime.parse(json['lastLoginAt'] as String),
      );
}
