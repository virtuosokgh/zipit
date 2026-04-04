import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/network/kakao_api.dart';
import '../../../models/address_result.dart';
import '../../../models/contract.dart';
import '../providers/contract_provider.dart';

/// 카카오 API Provider (계약 등록용)
final _kakaoApiProvider = Provider((ref) => KakaoApi());

class ContractRegisterScreen extends ConsumerStatefulWidget {
  const ContractRegisterScreen({super.key});

  @override
  ConsumerState<ContractRegisterScreen> createState() => _ContractRegisterScreenState();
}

class _ContractRegisterScreenState extends ConsumerState<ContractRegisterScreen> {
  ContractType _type = ContractType.jeonse;
  final _aptSearchController = TextEditingController();
  final _dongController = TextEditingController();
  final _hoController = TextEditingController();
  final _priceController = TextEditingController();
  final _monthlyRentController = TextEditingController();
  DateTime _contractDate = DateTime.now();
  DateTime? _balanceDate;
  DateTime? _moveInDate;

  // 주소 검색 관련
  List<AddressResult> _searchResults = [];
  bool _showSearchResults = false;
  bool _isSearching = false;
  Timer? _searchDebounce;

  // 선택된 주소 정보
  String _selectedAptName = '';
  String _selectedFullAddress = '';

  @override
  void dispose() {
    _aptSearchController.dispose();
    _dongController.dispose();
    _hoController.dispose();
    _priceController.dispose();
    _monthlyRentController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  bool get _canSubmit =>
      _selectedAptName.isNotEmpty &&
      _selectedFullAddress.isNotEmpty &&
      _priceController.text.isNotEmpty;

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.length < 2) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _isSearching = true);
      try {
        final api = ref.read(_kakaoApiProvider);
        final results = await api.searchAddress(query);
        if (mounted) {
          setState(() {
            _searchResults = results;
            _showSearchResults = true;
            _isSearching = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isSearching = false);
      }
    });
  }

  Future<void> _selectAddress(AddressResult address) async {
    // 지역코드가 필요하면 좌표로 조회
    if (address.needsRegionCode && address.latitude != 0) {
      final api = ref.read(_kakaoApiProvider);
      final code = await api.getRegionCode(address.latitude, address.longitude);
      address = address.withRegionCode(code);
    }

    if (!mounted) return;
    setState(() {
      _selectedAptName = address.buildingName ?? address.addressName;
      _selectedFullAddress = address.addressName;
      _aptSearchController.text = _selectedAptName;
      _showSearchResults = false;
      _searchResults = [];
    });

    FocusScope.of(context).unfocus();
  }

  void _clearSelection() {
    setState(() {
      _selectedAptName = '';
      _selectedFullAddress = '';
      _aptSearchController.clear();
    });
  }

  void _submit() {
    final detailParts = <String>[];
    if (_dongController.text.isNotEmpty) detailParts.add('${_dongController.text}동');
    if (_hoController.text.isNotEmpty) detailParts.add('${_hoController.text}호');
    final detailAddress = detailParts.isNotEmpty ? detailParts.join(' ') : null;

    final contract = Contract(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: _type,
      address: _selectedFullAddress,
      detailAddress: detailAddress,
      aptName: _selectedAptName,
      price: int.tryParse(_priceController.text.replaceAll(',', '')) ?? 0,
      monthlyRent: _type == ContractType.monthly
          ? int.tryParse(_monthlyRentController.text.replaceAll(',', ''))
          : null,
      contractDate: _contractDate,
      balanceDate: _balanceDate,
      moveInDate: _moveInDate,
      checklist: Contract.defaultChecklist(_type),
    );

    ref.read(contractsProvider.notifier).addContract(contract);
    context.pop();
  }

  Future<void> _pickDate(String label, DateTime? initial, ValueChanged<DateTime> onPicked) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: label,
    );
    if (date != null) onPicked(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('계약 등록'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.pop()),
      ),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
          setState(() => _showSearchResults = false);
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 계약 유형
              const Text('계약 유형', style: AppTypography.body2Bold),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: ContractType.values.map((t) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: t != ContractType.monthly ? AppSpacing.sm : 0),
                    child: ChoiceChip(
                      label: Text(t.label),
                      selected: _type == t,
                      onSelected: (_) => setState(() => _type = t),
                      labelStyle: AppTypography.label2.copyWith(
                        color: _type == t ? AppColors.primary : AppColors.textSecondary,
                      ),
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(height: AppSpacing.xxl),

              // 아파트 검색
              const Text('아파트 검색', style: AppTypography.body2Bold),
              const SizedBox(height: AppSpacing.sm),
              if (_selectedAptName.isNotEmpty && !_showSearchResults)
                // 선택된 아파트 표시
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.cardPadding),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.apartment, color: AppColors.primary, size: 20),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_selectedAptName, style: AppTypography.body2Bold),
                            const SizedBox(height: 2),
                            Text(_selectedFullAddress, style: AppTypography.caption1.copyWith(color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: _clearSelection,
                        child: const Icon(Icons.close, size: 18, color: AppColors.gray400),
                      ),
                    ],
                  ),
                )
              else
                // 검색 입력
                Column(
                  children: [
                    TextField(
                      controller: _aptSearchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: '아파트 이름을 검색하세요',
                        prefixIcon: const Icon(Icons.search, color: AppColors.gray500),
                        suffixIcon: _isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                              )
                            : _aptSearchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.close, color: AppColors.gray500, size: 20),
                                    onPressed: () {
                                      _aptSearchController.clear();
                                      setState(() {
                                        _searchResults = [];
                                        _showSearchResults = false;
                                      });
                                    },
                                  )
                                : null,
                      ),
                    ),
                    // 검색 결과 리스트
                    if (_showSearchResults && _searchResults.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        constraints: const BoxConstraints(maxHeight: 250),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          border: Border.all(color: AppColors.borderLight),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.textPrimary.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: _searchResults.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final r = _searchResults[i];
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 20),
                              title: Text(
                                r.buildingName ?? r.addressName,
                                style: AppTypography.body2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                r.addressName,
                                style: AppTypography.caption2.copyWith(color: AppColors.textTertiary),
                                overflow: TextOverflow.ellipsis,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                              onTap: () => _selectAddress(r),
                            );
                          },
                        ),
                      ),
                    if (_showSearchResults && _searchResults.isEmpty && !_isSearching)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: const Center(
                          child: Text('검색 결과가 없어요', style: AppTypography.caption1),
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: AppSpacing.lg),

              // 상세주소 (동/호수)
              if (_selectedAptName.isNotEmpty) ...[
                const Text('상세주소', style: AppTypography.body2Bold),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _dongController,
                        decoration: const InputDecoration(
                          hintText: '동 (예: 101)',
                          suffixText: '동',
                        ),
                        keyboardType: TextInputType.text,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: TextField(
                        controller: _hoController,
                        decoration: const InputDecoration(
                          hintText: '호수 (예: 1501)',
                          suffixText: '호',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
              ],

              // 가격
              Text(
                _type == ContractType.monthly ? '보증금 (만원)' : '${_type.label}가 (만원)',
                style: AppTypography.body2Bold,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _priceController,
                decoration: const InputDecoration(hintText: '예: 60000'),
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),

              if (_type == ContractType.monthly) ...[
                const SizedBox(height: AppSpacing.lg),
                const Text('월세 (만원)', style: AppTypography.body2Bold),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _monthlyRentController,
                  decoration: const InputDecoration(hintText: '예: 80'),
                  keyboardType: TextInputType.number,
                ),
              ],

              const SizedBox(height: AppSpacing.xxl),
              const Text('주요 일정', style: AppTypography.body2Bold),
              const SizedBox(height: AppSpacing.sm),

              _dateTile('계약일', _contractDate, (d) => setState(() => _contractDate = d)),
              _dateTile('잔금일', _balanceDate, (d) {
                setState(() {
                  _balanceDate = d;
                  // 잔금일 입력 시 입주일 자동 세팅 (아직 미입력인 경우)
                  _moveInDate ??= d;
                });
              }),
              _dateTile('입주일', _moveInDate, (d) => setState(() => _moveInDate = d)),

              if (_balanceDate != null && _moveInDate != null && _balanceDate == _moveInDate)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: AppSpacing.sm),
                  child: Text(
                    '입주일이 잔금일과 동일하게 설정되었어요. 필요 시 변경할 수 있어요.',
                    style: AppTypography.caption2.copyWith(color: AppColors.textTertiary),
                  ),
                ),

              const SizedBox(height: AppSpacing.xxxl),
              ElevatedButton(
                onPressed: _canSubmit ? _submit : null,
                child: const Text('등록하기'),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateTile(String label, DateTime? date, ValueChanged<DateTime> onPicked) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: ListTile(
        title: Text(label, style: AppTypography.body2),
        trailing: Text(
          date != null ? '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}' : '선택',
          style: AppTypography.body2.copyWith(color: date != null ? AppColors.primary : AppColors.textTertiary),
        ),
        onTap: () => _pickDate(label, date, onPicked),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }
}
