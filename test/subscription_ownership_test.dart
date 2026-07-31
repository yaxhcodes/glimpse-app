import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/services/subscription_service.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

void main() {
  test('receipt ownership conflict never reports purchase success', () {
    expect(
      SubscriptionService.purchaseOutcomeForError(
        PurchasesErrorCode.receiptAlreadyInUseError,
      ),
      SubscriptionPurchaseOutcome.ownedByAnotherAccount,
    );
  });

  test('restore keeps a receipt attached to its original account', () {
    expect(
      SubscriptionService.restoreOutcomeForError(
        PurchasesErrorCode.receiptAlreadyInUseError,
      ),
      SubscriptionRestoreOutcome.ownedByAnotherAccount,
    );
  });

  test('pending and cancelled purchases remain distinct outcomes', () {
    expect(
      SubscriptionService.purchaseOutcomeForError(
        PurchasesErrorCode.paymentPendingError,
      ),
      SubscriptionPurchaseOutcome.pending,
    );
    expect(
      SubscriptionService.purchaseOutcomeForError(
        PurchasesErrorCode.purchaseCancelledError,
      ),
      SubscriptionPurchaseOutcome.cancelled,
    );
  });
}
