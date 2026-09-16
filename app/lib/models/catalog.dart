class Category {
  const Category({
    required this.id,
    required this.slug,
    required this.name,
    this.nameMy,
    this.iconUrl,
  });

  final int id;
  final String slug;
  final String name;
  final String? nameMy;
  final String? iconUrl;

  String localisedName(bool burmese) => burmese && (nameMy?.isNotEmpty ?? false) ? nameMy! : name;

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: (json['id'] as num).toInt(),
        slug: json['slug'] as String,
        name: json['name'] as String,
        nameMy: json['nameMy'] as String?,
        iconUrl: json['iconUrl'] as String?,
      );
}

class ProductSummary {
  const ProductSummary({
    required this.id,
    required this.slug,
    required this.name,
    required this.categorySlug,
    required this.featured,
    required this.fulfillmentType,
    required this.inStock,
    this.nameMy,
    this.imageUrl,
    this.startingPrice,
  });

  final int id;
  final String slug;
  final String name;
  final String categorySlug;
  final bool featured;
  final String fulfillmentType;
  final bool inStock;
  final String? nameMy;
  final String? imageUrl;
  final int? startingPrice;

  String localisedName(bool burmese) => burmese && (nameMy?.isNotEmpty ?? false) ? nameMy! : name;

  factory ProductSummary.fromJson(Map<String, dynamic> json) => ProductSummary(
        id: (json['id'] as num).toInt(),
        slug: json['slug'] as String,
        name: json['name'] as String,
        categorySlug: json['categorySlug'] as String? ?? '',
        featured: json['featured'] as bool? ?? false,
        fulfillmentType: json['fulfillmentType'] as String? ?? 'MANUAL',
        inStock: json['inStock'] as bool? ?? true,
        nameMy: json['nameMy'] as String?,
        imageUrl: json['imageUrl'] as String?,
        startingPrice: (json['startingPrice'] as num?)?.toInt(),
      );
}

class ProductField {
  const ProductField({
    required this.key,
    required this.label,
    required this.inputType,
    required this.required,
    this.labelMy,
    this.placeholder,
    this.helpText,
    this.options = const [],
    this.validationRegex,
  });

  final String key;
  final String label;
  final String inputType;
  final bool required;
  final String? labelMy;
  final String? placeholder;
  final String? helpText;
  final List<String> options;
  final String? validationRegex;

  String localisedLabel(bool burmese) => burmese && (labelMy?.isNotEmpty ?? false) ? labelMy! : label;

  /// Mirrors the server-side check so the user sees the problem before paying.
  String? validate(String? value, bool burmese) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return required ? '${localisedLabel(burmese)} ${burmese ? 'ဖြည့်ပါ' : 'is required'}' : null;
    }
    final pattern = validationRegex;
    if (pattern != null && pattern.isNotEmpty && !RegExp('^(?:$pattern)\$').hasMatch(text)) {
      return burmese
          ? '${localisedLabel(burmese)} မမှန်ကန်ပါ'
          : 'That ${localisedLabel(burmese)} does not look right';
    }
    return null;
  }

  factory ProductField.fromJson(Map<String, dynamic> json) => ProductField(
        key: json['key'] as String,
        label: json['label'] as String,
        inputType: json['inputType'] as String? ?? 'TEXT',
        required: json['required'] as bool? ?? true,
        labelMy: json['labelMy'] as String?,
        placeholder: json['placeholder'] as String?,
        helpText: json['helpText'] as String?,
        options: (json['options'] as List<dynamic>? ?? []).map((e) => '$e').toList(),
        validationRegex: json['validationRegex'] as String?,
      );
}

class ProductVariant {
  const ProductVariant({
    required this.id,
    required this.sku,
    required this.name,
    required this.price,
    required this.maxPerOrder,
    required this.popularity,
    required this.inStock,
    this.nameMy,
    this.bonusText,
    this.description,
    this.compareAtPrice,
    this.imageUrl,
    this.remaining,
  });

  final int id;
  final String sku;
  final String name;
  final int price;
  final int maxPerOrder;
  final int popularity;
  final bool inStock;
  final String? nameMy;
  final String? bonusText;
  final String? description;
  final int? compareAtPrice;
  final String? imageUrl;
  final int? remaining;

  bool get isOnSale => compareAtPrice != null && compareAtPrice! > price;

  int get discountPercent =>
      isOnSale ? (((compareAtPrice! - price) / compareAtPrice!) * 100).round() : 0;

  bool get isLowStock => remaining != null && remaining! > 0 && remaining! <= 5;

  String localisedName(bool burmese) => burmese && (nameMy?.isNotEmpty ?? false) ? nameMy! : name;

  factory ProductVariant.fromJson(Map<String, dynamic> json) => ProductVariant(
        id: (json['id'] as num).toInt(),
        sku: json['sku'] as String,
        name: json['name'] as String,
        price: (json['price'] as num).toInt(),
        maxPerOrder: (json['maxPerOrder'] as num?)?.toInt() ?? 10,
        popularity: (json['popularity'] as num?)?.toInt() ?? 0,
        inStock: json['inStock'] as bool? ?? true,
        nameMy: json['nameMy'] as String?,
        bonusText: json['bonusText'] as String?,
        description: json['description'] as String?,
        compareAtPrice: (json['compareAtPrice'] as num?)?.toInt(),
        imageUrl: json['imageUrl'] as String?,
        remaining: (json['remaining'] as num?)?.toInt(),
      );
}

class ProductDetail {
  const ProductDetail({
    required this.id,
    required this.slug,
    required this.name,
    required this.fulfillmentType,
    required this.category,
    required this.fields,
    required this.variants,
    this.nameMy,
    this.description,
    this.descriptionMy,
    this.imageUrl,
    this.bannerUrl,
    this.instructions,
    this.instructionsMy,
  });

  final int id;
  final String slug;
  final String name;
  final String fulfillmentType;
  final Category category;
  final List<ProductField> fields;
  final List<ProductVariant> variants;
  final String? nameMy;
  final String? description;
  final String? descriptionMy;
  final String? imageUrl;
  final String? bannerUrl;
  final String? instructions;
  final String? instructionsMy;

  bool get isInstantDelivery => fulfillmentType == 'CODE_DELIVERY';

  String localisedName(bool burmese) => burmese && (nameMy?.isNotEmpty ?? false) ? nameMy! : name;

  String? localisedDescription(bool burmese) =>
      burmese && (descriptionMy?.isNotEmpty ?? false) ? descriptionMy : description;

  String? localisedInstructions(bool burmese) =>
      burmese && (instructionsMy?.isNotEmpty ?? false) ? instructionsMy : instructions;

  factory ProductDetail.fromJson(Map<String, dynamic> json) => ProductDetail(
        id: (json['id'] as num).toInt(),
        slug: json['slug'] as String,
        name: json['name'] as String,
        fulfillmentType: json['fulfillmentType'] as String? ?? 'MANUAL',
        category: Category.fromJson(json['category'] as Map<String, dynamic>),
        fields: (json['fields'] as List<dynamic>? ?? [])
            .map((e) => ProductField.fromJson(e as Map<String, dynamic>))
            .toList(),
        variants: (json['variants'] as List<dynamic>? ?? [])
            .map((e) => ProductVariant.fromJson(e as Map<String, dynamic>))
            .toList(),
        nameMy: json['nameMy'] as String?,
        description: json['description'] as String?,
        descriptionMy: json['descriptionMy'] as String?,
        imageUrl: json['imageUrl'] as String?,
        bannerUrl: json['bannerUrl'] as String?,
        instructions: json['instructions'] as String?,
        instructionsMy: json['instructionsMy'] as String?,
      );
}

class Banner {
  const Banner({
    required this.id,
    required this.imageUrl,
    required this.linkType,
    this.title,
    this.linkValue,
  });

  final int id;
  final String imageUrl;
  final String linkType;
  final String? title;
  final String? linkValue;

  factory Banner.fromJson(Map<String, dynamic> json) => Banner(
        id: (json['id'] as num).toInt(),
        imageUrl: json['imageUrl'] as String,
        linkType: json['linkType'] as String? ?? 'NONE',
        title: json['title'] as String?,
        linkValue: json['linkValue'] as String?,
      );
}

class HomeData {
  const HomeData({
    required this.banners,
    required this.categories,
    required this.featured,
    required this.maintenance,
    required this.maintenanceMessage,
  });

  final List<Banner> banners;
  final List<Category> categories;
  final List<ProductSummary> featured;
  final bool maintenance;
  final String maintenanceMessage;

  factory HomeData.fromJson(Map<String, dynamic> json) => HomeData(
        banners: (json['banners'] as List<dynamic>? ?? [])
            .map((e) => Banner.fromJson(e as Map<String, dynamic>))
            .toList(),
        categories: (json['categories'] as List<dynamic>? ?? [])
            .map((e) => Category.fromJson(e as Map<String, dynamic>))
            .toList(),
        featured: (json['featured'] as List<dynamic>? ?? [])
            .map((e) => ProductSummary.fromJson(e as Map<String, dynamic>))
            .toList(),
        maintenance: json['maintenance'] as bool? ?? false,
        maintenanceMessage: json['maintenanceMessage'] as String? ?? '',
      );
}
