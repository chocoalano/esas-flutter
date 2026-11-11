import 'package:get/get.dart';

import '../../../../core/network/api_exception.dart';
import '../../data/models/cash_advance.dart';
import '../../data/models/employee_loan.dart';
import '../../data/repositories/payroll_repository.dart';

class ProfileFinancialController extends GetxController {
  ProfileFinancialController({required PayrollRepository repository})
      : _repository = repository;

  final PayrollRepository _repository;

  final isLoading = true.obs;
  final Rxn<ApiException> error = Rxn<ApiException>();
  final RxList<EmployeeLoan> loans = <EmployeeLoan>[].obs;
  final RxDouble outstandingTotal = 0.0.obs;
  final RxList<CashAdvance> advances = <CashAdvance>[].obs;
  final RxDouble unaccountedTotal = 0.0.obs;

  @override
  void onInit() {
    super.onInit();
    loadFinancials();
  }

  Future<void> loadFinancials() async {
    isLoading.value = true;
    error.value = null;

    try {
      final loansRes = await _repository.loans();
      loans.assignAll(loansRes.loans);
      outstandingTotal.value = loansRes.outstandingTotal;

      final advancesRes = await _repository.advances();
      advances.assignAll(advancesRes.advances);
      unaccountedTotal.value = advancesRes.unaccountedTotal;
    } on ApiException catch (e) {
      error.value = e;
    } catch (e) {
      error.value = ApiException(e.toString());
    } finally {
      isLoading.value = false;
    }
  }
}

