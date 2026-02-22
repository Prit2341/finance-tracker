import 'package:finance_tracker/features/subscriptions/data/datasources/subscription_local_datasource.dart';
import 'package:finance_tracker/features/subscriptions/domain/entities/subscription.dart';
import 'package:finance_tracker/features/subscriptions/domain/repositories/subscription_repository.dart';

class SubscriptionRepositoryImpl implements SubscriptionRepository {
  final SubscriptionLocalDatasource _datasource;

  SubscriptionRepositoryImpl(this._datasource);

  @override
  Future<List<Subscription>> getAll() => _datasource.getAll();

  @override
  Future<List<Subscription>> getActive() => _datasource.getActive();

  @override
  Future<void> add(Subscription subscription) => _datasource.insert(subscription);

  @override
  Future<void> update(Subscription subscription) => _datasource.update(subscription);

  @override
  Future<void> delete(String id) => _datasource.delete(id);
}
