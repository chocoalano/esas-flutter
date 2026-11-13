import 'package:get/get.dart';

import '../../../../core/network/api_exception.dart';
import '../../data/models/itms_ticket.dart';
import '../../data/repositories/itms_repository.dart';

/// One of the requester's tickets, read fresh from the server (FUNC-D04).
class ItmsTicketDetailController extends GetxController {
  ItmsTicketDetailController({
    required ItmsRepository repository,
    required this.ticketId,
  }) : _repository = repository;

  final ItmsRepository _repository;
  final int ticketId;

  final Rxn<ItmsTicket> ticket = Rxn<ItmsTicket>();
  final RxBool isLoading = true.obs;
  final Rxn<ApiException> error = Rxn<ApiException>();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    error.value = null;
    try {
      ticket.value = await _repository.ticket(ticketId);
    } on ApiException catch (e) {
      error.value = e;
    } finally {
      isLoading.value = false;
    }
  }
}
