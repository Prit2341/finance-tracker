import '../entities/subscription.dart';

abstract class SubscriptionRepository {
  Future<List<Subscription>> getAll();
  Future<List<Subscription>> getActive();
  Future<void> add(Subscription subscription);
  Future<void> update(Subscription subscription);
  Future<void> delete(String id);
}
