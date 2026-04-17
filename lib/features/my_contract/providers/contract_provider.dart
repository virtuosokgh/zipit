import 'dart:developer' as dev;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/contract.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/services/notification_service.dart';

final _supabase = Supabase.instance.client;

final contractsProvider =
    StateNotifierProvider<ContractsNotifier, List<Contract>>((ref) {
  return ContractsNotifier(ref);
});

class ContractsNotifier extends StateNotifier<List<Contract>> {
  final Ref _ref;

  ContractsNotifier(this._ref) : super([]) {
    _loadContracts();
    // Auth 상태 변경 감시: 로그아웃 시 초기화, 로그인 시 다시 로드
    _ref.listen(authStateProvider, (prev, next) {
      final session = next.valueOrNull;
      if (session != null) {
        _loadContracts();
      } else {
        state = [];
      }
    });
  }

  /// Supabase에서 현재 유저의 계약 목록 로드
  Future<void> _loadContracts() async {
    final user = currentUser;
    if (user == null) return;

    try {
      final data = await _supabase
          .from('contracts')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      state = (data as List).map((json) => Contract.fromJson(json)).toList();
    } catch (e) {
      dev.log('계약 목록 로드 실패: $e', name: 'Contract');
    }
  }

  /// 계약 추가 → Supabase insert 후 로컬 반영
  Future<void> addContract(Contract contract) async {
    final user = currentUser;
    if (user == null) return;

    // 낙관적 업데이트: 먼저 로컬에 반영
    state = [...state, contract];

    // 알림 예약
    _scheduleNotifications(contract);

    try {
      final json = contract.toJson();
      json['user_id'] = user.id;
      json['updated_at'] = DateTime.now().toIso8601String();
      await _supabase.from('contracts').insert(json);
    } catch (e) {
      dev.log('계약 추가 Supabase 저장 실패 (로컬 유지): $e', name: 'Contract');
    }
  }

  /// 계약 상태 변경
  Future<void> updateStatus(String id, ContractStatus status) async {
    final index = state.indexWhere((c) => c.id == id);
    if (index == -1) return;

    final updated = state[index].copyWith(status: status);
    state = [
      for (int i = 0; i < state.length; i++)
        if (i == index) updated else state[i],
    ];

    try {
      await _supabase.from('contracts').update({
        'status': status.name,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
    } catch (e) {
      dev.log('계약 상태 Supabase 업데이트 실패: $e', name: 'Contract');
    }
  }

  /// 체크리스트 토글
  Future<void> toggleChecklist(String contractId, String checklistId) async {
    final index = state.indexWhere((c) => c.id == contractId);
    if (index == -1) return;

    final contract = state[index];
    final newChecklist = contract.checklist
        .map((item) => item.id == checklistId
            ? item.copyWith(isCompleted: !item.isCompleted)
            : item)
        .toList();

    final updated = contract.copyWith(checklist: newChecklist);
    state = [
      for (int i = 0; i < state.length; i++)
        if (i == index) updated else state[i],
    ];

    try {
      await _supabase.from('contracts').update({
        'checklist': newChecklist.map((item) => item.toJson()).toList(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', contractId);
    } catch (e) {
      dev.log('체크리스트 Supabase 업데이트 실패: $e', name: 'Contract');
    }
  }

  /// 계약 삭제
  Future<void> removeContract(String id) async {
    final previous = state;
    state = state.where((c) => c.id != id).toList();

    // 알림 취소
    NotificationService.cancelAllForContract(id);

    try {
      await _supabase.from('contracts').delete().eq('id', id);
    } catch (e) {
      dev.log('계약 삭제 실패, 로컬 상태 복원: $e', name: 'Contract');
      state = previous;
    }
  }

  /// 계약 전체 업데이트 (날짜 변경 등 범용)
  Future<void> updateContract(Contract contract) async {
    final index = state.indexWhere((c) => c.id == contract.id);
    if (index == -1) return;

    state = [
      for (int i = 0; i < state.length; i++)
        if (i == index) contract else state[i],
    ];

    try {
      final json = contract.toJson();
      json['updated_at'] = DateTime.now().toIso8601String();
      await _supabase.from('contracts').update(json).eq('id', contract.id);
    } catch (e) {
      dev.log('계약 업데이트 실패: $e', name: 'Contract');
    }
  }

  /// 단계별 날짜 업데이트
  Future<void> updateStepDate(
      String id, ContractStatus step, DateTime? date) async {
    final index = state.indexWhere((c) => c.id == id);
    if (index == -1) return;

    final contract = state[index];
    Contract updated;
    String dbField;

    switch (step) {
      case ContractStatus.preparing:
        updated = contract.copyWith(contractDate: date);
        dbField = 'contract_date';
      case ContractStatus.deposit:
        updated = contract.copyWith(depositDate: date);
        dbField = 'deposit_date';
      case ContractStatus.interim:
        updated = contract.copyWith(interimDate: date);
        dbField = 'interim_date';
      case ContractStatus.balance:
        updated = contract.copyWith(balanceDate: date);
        dbField = 'balance_date';
      case ContractStatus.move:
        updated = contract.copyWith(moveInDate: date);
        dbField = 'move_in_date';
      case ContractStatus.completed:
        updated = contract;
        dbField = '';
    }

    if (dbField.isEmpty) return;

    state = [
      for (int i = 0; i < state.length; i++)
        if (i == index) updated else state[i],
    ];

    // 알림 재예약
    _scheduleNotifications(updated);

    try {
      await _supabase.from('contracts').update({
        dbField: date?.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
    } catch (e) {
      dev.log('단계별 날짜 업데이트 실패: $e', name: 'Contract');
    }
  }

  /// 계약 알림 예약
  void _scheduleNotifications(Contract contract) {
    NotificationService.scheduleContractNotifications(
      contractId: contract.id,
      aptName: contract.aptName,
      balanceDate: contract.balanceDate,
      moveInDate: contract.moveInDate,
    );
  }

  /// 수동 새로고침
  Future<void> refresh() async {
    await _loadContracts();
  }
}
