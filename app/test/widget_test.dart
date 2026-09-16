import 'package:dia_shop/core/api_exception.dart';
import 'package:dia_shop/core/format.dart';
import 'package:dia_shop/models/catalog.dart';
import 'package:dia_shop/models/order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Format', () {
    test('money groups thousands and appends the currency', () {
      expect(Format.money(12400), '12,400 Ks');
      expect(Format.money(0), '0 Ks');
    });

    test('signedMoney marks credits with a plus and keeps the minus on debits', () {
      expect(Format.signedMoney(50000), '+50,000 Ks');
      expect(Format.signedMoney(-12400), '-12,400 Ks');
    });
  });

  group('ProductField.validate', () {
    const playerId = ProductField(
      key: 'player_id',
      label: 'Player ID',
      inputType: 'NUMBER',
      required: true,
      validationRegex: r'^[0-9]{5,15}$',
    );

    test('rejects an empty required value', () {
      expect(playerId.validate('', false), isNotNull);
    });

    test('rejects a value that does not match the pattern', () {
      expect(playerId.validate('abc', false), isNotNull);
      expect(playerId.validate('123', false), isNotNull);
    });

    test('accepts a valid value', () {
      expect(playerId.validate('123456789', false), isNull);
    });

    test('allows an empty value when the field is optional', () {
      const optional = ProductField(
        key: 'note',
        label: 'Note',
        inputType: 'TEXT',
        required: false,
      );
      expect(optional.validate('', false), isNull);
    });
  });

  group('ProductVariant', () {
    test('reports a sale only when the compare price is higher', () {
      const onSale = ProductVariant(
        id: 1, sku: 'A', name: 'A', price: 8000, compareAtPrice: 10000,
        maxPerOrder: 5, popularity: 0, inStock: true,
      );
      const notOnSale = ProductVariant(
        id: 2, sku: 'B', name: 'B', price: 10000, compareAtPrice: 10000,
        maxPerOrder: 5, popularity: 0, inStock: true,
      );
      expect(onSale.isOnSale, isTrue);
      expect(onSale.discountPercent, 20);
      expect(notOnSale.isOnSale, isFalse);
    });
  });

  group('OrderStatus', () {
    test('only a pending order can be cancelled by the buyer', () {
      expect(OrderStatus.pending.canCancel, isTrue);
      expect(OrderStatus.processing.canCancel, isFalse);
      expect(OrderStatus.completed.canCancel, isFalse);
    });

    test('parses unknown values as pending rather than throwing', () {
      expect(OrderStatus.parse('SOMETHING_NEW'), OrderStatus.pending);
      expect(OrderStatus.parse('COMPLETED'), OrderStatus.completed);
    });
  });

  group('ApiException', () {
    test('recognises the codes the UI branches on', () {
      final insufficient = ApiException(code: 'INSUFFICIENT_BALANCE', message: 'x');
      expect(insufficient.isInsufficientBalance, isTrue);
      expect(insufficient.isOutOfStock, isFalse);
    });
  });

  group('OrderQuote', () {
    test('shortfall is the amount still missing from the wallet', () {
      const quote = OrderQuote(
        subtotal: 20000, total: 20000, walletBalance: 12000,
        balanceAfter: -8000, affordable: false, lines: [],
      );
      expect(quote.shortfall, 8000);
    });

    test('shortfall is zero when the balance covers the order', () {
      const quote = OrderQuote(
        subtotal: 5000, total: 5000, walletBalance: 12000,
        balanceAfter: 7000, affordable: true, lines: [],
      );
      expect(quote.shortfall, 0);
    });
  });
}
