import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finance_tracker/features/subscriptions/data/datasources/subscription_local_datasource.dart';
import 'package:finance_tracker/features/subscriptions/data/repositories/subscription_repository_impl.dart';
import 'package:finance_tracker/features/subscriptions/domain/entities/subscription.dart';
import 'package:finance_tracker/features/subscriptions/domain/repositories/subscription_repository.dart';

final subscriptionDatasourceProvider = Provider<SubscriptionLocalDatasource>(
  (ref) => SubscriptionLocalDatasource(),
);

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>(
  (ref) => SubscriptionRepositoryImpl(ref.watch(subscriptionDatasourceProvider)),
);

final subscriptionsProvider =
    AsyncNotifierProvider<SubscriptionsNotifier, List<Subscription>>(
  SubscriptionsNotifier.new,
);

class SubscriptionsNotifier extends AsyncNotifier<List<Subscription>> {
  @override
  Future<List<Subscription>> build() async {
    final repo = ref.watch(subscriptionRepositoryProvider);
    return repo.getActive();
  }

  Future<void> add(Subscription subscription) async {
    final repo = ref.read(subscriptionRepositoryProvider);
    await repo.add(subscription);
    ref.invalidateSelf();
  }

  Future<void> updateSubscription(Subscription subscription) async {
    final repo = ref.read(subscriptionRepositoryProvider);
    await repo.update(subscription);
    ref.invalidateSelf();
  }

  Future<void> delete(String id) async {
    final repo = ref.read(subscriptionRepositoryProvider);
    await repo.delete(id);
    ref.invalidateSelf();
  }

  Future<void> toggleActive(Subscription subscription) async {
    final updated = subscription.copyWith(
      isActive: !subscription.isActive,
      updatedAt: DateTime.now(),
    );
    await updateSubscription(updated);
  }
}

final monthlySubscriptionTotalProvider = Provider<double>((ref) {
  final subs = ref.watch(subscriptionsProvider).valueOrNull ?? [];
  return subs.fold(0.0, (sum, s) => sum + s.monthlyAmount);
});
