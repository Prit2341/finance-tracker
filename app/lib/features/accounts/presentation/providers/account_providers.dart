import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finance_tracker/features/accounts/data/datasources/account_local_datasource.dart';
import 'package:finance_tracker/features/accounts/data/repositories/account_repository_impl.dart';
import 'package:finance_tracker/features/accounts/domain/entities/bank_account.dart';
import 'package:finance_tracker/features/accounts/domain/repositories/account_repository.dart';

final accountDatasourceProvider = Provider<AccountLocalDatasource>(
  (ref) => AccountLocalDatasource(),
);

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => AccountRepositoryImpl(ref.watch(accountDatasourceProvider)),
);

final accountsProvider =
    AsyncNotifierProvider<AccountsNotifier, List<BankAccount>>(
  AccountsNotifier.new,
);

class AccountsNotifier extends AsyncNotifier<List<BankAccount>> {
  @override
  Future<List<BankAccount>> build() async {
    final repo = ref.watch(accountRepositoryProvider);
    return repo.getAll();
  }

  Future<void> add(BankAccount account) async {
    final repo = ref.read(accountRepositoryProvider);
    await repo.add(account);
    ref.invalidateSelf();
  }

  Future<void> updateAccount(BankAccount account) async {
    final repo = ref.read(accountRepositoryProvider);
    await repo.update(account);
    ref.invalidateSelf();
  }

  Future<void> delete(String id) async {
    final repo = ref.read(accountRepositoryProvider);
    await repo.delete(id);
    ref.invalidateSelf();
  }
}
