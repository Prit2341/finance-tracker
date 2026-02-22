import 'package:finance_tracker/features/accounts/domain/entities/bank_account.dart';

abstract class AccountRepository {
  Future<List<BankAccount>> getAll();
  Future<BankAccount?> getById(String id);
  Future<void> add(BankAccount account);
  Future<void> update(BankAccount account);
  Future<void> delete(String id);
}
