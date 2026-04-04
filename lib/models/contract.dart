/// 계약 유형
enum ContractType {
  buy('매매'),
  jeonse('전세'),
  monthly('월세');

  final String label;
  const ContractType(this.label);
}

/// 계약 상태
enum ContractStatus {
  preparing('계약 준비', 0),
  deposit('계약금 납부', 1),
  interim('중도금 납부', 2),
  balance('잔금 납부', 3),
  move('이사/입주', 4),
  completed('계약 완료', 5);

  final String label;
  final int order;
  const ContractStatus(this.label, this.order);
}

/// 체크리스트 항목
class ChecklistItem {
  final String id;
  final String title;
  final String? description;
  final bool isCompleted;
  final DateTime? dueDate;

  ChecklistItem({
    required this.id,
    required this.title,
    this.description,
    this.isCompleted = false,
    this.dueDate,
  });

  ChecklistItem copyWith({bool? isCompleted}) => ChecklistItem(
        id: id,
        title: title,
        description: description,
        isCompleted: isCompleted ?? this.isCompleted,
        dueDate: dueDate,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'is_completed': isCompleted,
        'due_date': dueDate?.toIso8601String(),
      };

  factory ChecklistItem.fromJson(Map<String, dynamic> json) => ChecklistItem(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        isCompleted: json['is_completed'] as bool? ?? false,
        dueDate: json['due_date'] != null
            ? DateTime.parse(json['due_date'] as String)
            : null,
      );
}

/// 계약 모델
class Contract {
  final String id;
  final ContractType type;
  final ContractStatus status;
  final String address;
  final String? detailAddress; // 상세주소 (동/호수)
  final String aptName;
  final int price; // 만원
  final int? monthlyRent; // 월세 (만원)
  final DateTime contractDate;
  final DateTime? depositDate; // 계약금 납부일
  final DateTime? interimDate; // 중도금 납부일
  final DateTime? balanceDate;
  final DateTime? moveInDate;
  final List<ChecklistItem> checklist;
  final DateTime createdAt;

  Contract({
    required this.id,
    required this.type,
    this.status = ContractStatus.preparing,
    required this.address,
    this.detailAddress,
    required this.aptName,
    required this.price,
    this.monthlyRent,
    required this.contractDate,
    this.depositDate,
    this.interimDate,
    this.balanceDate,
    this.moveInDate,
    this.checklist = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 해당 계약 단계의 날짜 반환
  DateTime? dateForStatus(ContractStatus status) {
    switch (status) {
      case ContractStatus.preparing:
        return contractDate;
      case ContractStatus.deposit:
        return depositDate;
      case ContractStatus.interim:
        return interimDate;
      case ContractStatus.balance:
        return balanceDate;
      case ContractStatus.move:
        return moveInDate;
      case ContractStatus.completed:
        return null;
    }
  }

  /// 다음 중요 일정까지 D-day
  int? get nextDday {
    final now = DateTime.now();
    final dates = [
      if (balanceDate != null && balanceDate!.isAfter(now)) balanceDate!,
      if (moveInDate != null && moveInDate!.isAfter(now)) moveInDate!,
    ];
    if (dates.isEmpty) return null;
    dates.sort();
    return dates.first.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  Contract copyWith({
    String? id,
    ContractType? type,
    ContractStatus? status,
    String? address,
    String? detailAddress,
    String? aptName,
    int? price,
    int? monthlyRent,
    DateTime? contractDate,
    DateTime? depositDate,
    DateTime? interimDate,
    DateTime? balanceDate,
    DateTime? moveInDate,
    List<ChecklistItem>? checklist,
    DateTime? createdAt,
  }) =>
      Contract(
        id: id ?? this.id,
        type: type ?? this.type,
        status: status ?? this.status,
        address: address ?? this.address,
        detailAddress: detailAddress ?? this.detailAddress,
        aptName: aptName ?? this.aptName,
        price: price ?? this.price,
        monthlyRent: monthlyRent ?? this.monthlyRent,
        contractDate: contractDate ?? this.contractDate,
        depositDate: depositDate ?? this.depositDate,
        interimDate: interimDate ?? this.interimDate,
        balanceDate: balanceDate ?? this.balanceDate,
        moveInDate: moveInDate ?? this.moveInDate,
        checklist: checklist ?? this.checklist,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'status': status.name,
        'address': address,
        'detail_address': detailAddress,
        'apt_name': aptName,
        'price': price,
        'monthly_rent': monthlyRent,
        'contract_date': contractDate.toIso8601String(),
        'deposit_date': depositDate?.toIso8601String(),
        'interim_date': interimDate?.toIso8601String(),
        'balance_date': balanceDate?.toIso8601String(),
        'move_in_date': moveInDate?.toIso8601String(),
        'checklist': checklist.map((e) => e.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
      };

  factory Contract.fromJson(Map<String, dynamic> json) => Contract(
        id: json['id'] as String,
        type: ContractType.values.byName(json['type'] as String),
        status: ContractStatus.values.byName(json['status'] as String),
        address: json['address'] as String,
        detailAddress: json['detail_address'] as String?,
        aptName: json['apt_name'] as String,
        price: json['price'] as int,
        monthlyRent: json['monthly_rent'] as int?,
        contractDate: DateTime.parse(json['contract_date'] as String),
        depositDate: json['deposit_date'] != null
            ? DateTime.parse(json['deposit_date'] as String)
            : null,
        interimDate: json['interim_date'] != null
            ? DateTime.parse(json['interim_date'] as String)
            : null,
        balanceDate: json['balance_date'] != null
            ? DateTime.parse(json['balance_date'] as String)
            : null,
        moveInDate: json['move_in_date'] != null
            ? DateTime.parse(json['move_in_date'] as String)
            : null,
        checklist: (json['checklist'] as List<dynamic>?)
                ?.map((e) =>
                    ChecklistItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : null,
      );

  /// 기본 체크리스트 생성
  static List<ChecklistItem> defaultChecklist(ContractType type) {
    final common = [
      ChecklistItem(id: '1', title: '등기부등본 확인', description: '소유권, 근저당, 가압류 확인'),
      ChecklistItem(id: '2', title: '건축물대장 확인', description: '위반건축물 여부 확인'),
      ChecklistItem(id: '3', title: '신분증 확인', description: '임대인/매도인 본인 확인'),
      ChecklistItem(id: '4', title: '계약서 특약사항 확인'),
    ];

    if (type == ContractType.jeonse) {
      return [
        ...common,
        ChecklistItem(id: '5', title: '전세보증보험 가입 가능 확인'),
        ChecklistItem(id: '6', title: '확정일자 받기', description: '전입신고 후 주민센터'),
        ChecklistItem(id: '7', title: '전입신고', description: '이사 당일'),
      ];
    } else if (type == ContractType.monthly) {
      return [
        ...common,
        ChecklistItem(id: '5', title: '확정일자 받기'),
        ChecklistItem(id: '6', title: '전입신고'),
      ];
    } else {
      return [
        ...common,
        ChecklistItem(id: '5', title: '대출 심사 완료'),
        ChecklistItem(id: '6', title: '잔금 준비'),
        ChecklistItem(id: '7', title: '소유권 이전 등기'),
      ];
    }
  }
}
