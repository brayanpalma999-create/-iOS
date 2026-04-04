import "package:flutter/material.dart";

import "../models/operations_model.dart";
import "../services/operations_service.dart";

class OperationsProvider extends ChangeNotifier {
  OperationsProvider({required OperationsService operationsService})
    : _operationsService = operationsService;

  final OperationsService _operationsService;

  OperationsSummaryModel? _summary;
  bool _loading = false;
  String? _error;

  OperationsSummaryModel? get summary => _summary;
  bool get loading => _loading;
  String? get error => _error;
  bool get hasData => _summary != null;

  Future<void> refresh({bool silent = false}) async {
    if (_loading) return;
    if (!silent) {
      _loading = true;
      notifyListeners();
    }
    try {
      final next = await _operationsService.fetchSummary();
      if (next != null) {
        _summary = next;
        _error = null;
      } else {
        _error ??= "No se pudo cargar operacion";
      }
    } catch (error) {
      _error = error.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
