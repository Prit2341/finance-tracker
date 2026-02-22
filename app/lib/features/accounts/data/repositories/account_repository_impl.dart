import 'package:finance_tracker/features/accounts/data/datasources/account_local_datasource.dart';
import 'package:finance_tracker/features/accounts/domain/entities/bank_account.dart';
import 'package:finance_tracker/features/accounts/domain/repositories/account_repository.dart';

class AccountRepositoryImpl implements AccountRepository {
  final AccountLocalDatasource _datasource;

  AccountRepositoryImpl(this._datasource);

  @override
  Future<List<BankAccount>> getAll() => _datasource.getAll();

  @override
  Future<BankAccount?> getById(String id) => _datasource.getById(id);

  @override
  Future<void> add(BankAccount account) => _datasource.insert(account);

  @override
  Future<void> update(BankAccount account) => _datasource.update(account);

  @override
  Future<void> delete(String id) => _datasource.delete(id);
}
