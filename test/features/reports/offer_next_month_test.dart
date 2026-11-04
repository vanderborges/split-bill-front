import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_front/features/events/models/event_model.dart';
import 'package:split_bill_front/features/events/services/events_repository.dart';
import 'package:split_bill_front/features/groups/models/group_member_model.dart';
import 'package:split_bill_front/features/groups/services/groups_repository.dart';
import 'package:split_bill_front/features/reports/models/monthly_report_model.dart';
import 'package:split_bill_front/features/reports/pages/reports_page.dart';
import 'package:split_bill_front/features/reports/services/reports_repository.dart';

EventModel _month(int month, String status) => EventModel(
      id: 'e$month',
      name: '$month/2026',
      description: null,
      type: 'MONTHLY',
      status: status,
      groupId: 'g1',
      monthId: 'm$month',
      month: month,
      year: 2026,
    );

class _FakeEvents extends EventsRepository {
  _FakeEvents(this.groupEvents, {this.onList}) : super(Dio());

  final List<EventModel> groupEvents;
  final VoidCallback? onList;
  final created = <String>[];

  @override
  Future<EventModel> startSettlement(String id,
      {String? consolidateToEventId, String? receiverUserId}) async {
    return _month(11, 'SETTLING');
  }

  @override
  Future<List<EventModel>> list(
      {String? viewerUserId,
      String? groupId,
      bool includeRemoved = false}) async {
    onList?.call();
    // A resposta chega depois de a tela já ter atualizado.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return groupEvents;
  }

  @override
  Future<EventModel> create({
    required String name,
    String? description,
    required String type,
    String? monthId,
    int? month,
    int? year,
    required String groupId,
    List<String>? continueInstallmentGroupIds,
  }) async {
    created.add(name);
    return _month(month!, 'OPEN');
  }
}

class _FakeGroups extends GroupsRepository {
  _FakeGroups() : super(Dio());

  @override
  Future<List<GroupMemberModel>> listMembers(String groupId,
          {String? viewerUserId,
          String? eventId,
          bool includeRemoved = false}) async =>
      const [];
}

class _FakeReports extends ReportsRepository {
  _FakeReports() : super(Dio());

  @override
  Future<MonthlyReportModel> getEventReport(String eventId) async =>
      throw StateError('sem saldo no teste');
}

/// Tela com o botão "Fechar evento". [visible] false tira o botão do ar, como
/// a tela de Saldos ao recarregar depois de abrir o pagamento.
Future<void> _pump(WidgetTester tester, EventsRepository events,
    ValueNotifier<bool> visible) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      eventsRepositoryProvider.overrideWithValue(events),
      groupsRepositoryProvider.overrideWithValue(_FakeGroups()),
      reportsRepositoryProvider.overrideWithValue(_FakeReports()),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: ValueListenableBuilder<bool>(
          valueListenable: visible,
          builder: (context, show, _) => show
              ? Consumer(
                  builder: (context, ref, _) => TextButton(
                    onPressed: () =>
                        confirmStartSettlement(context, ref, 'g1', 'e11'),
                    child: const Text('abrir'),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Fechar evento'));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sem mês seguinte: "Criar" cria aberto e sem despesas',
      (tester) async {
    final events = _FakeEvents([_month(11, 'SETTLING')]);
    await _pump(tester, events, ValueNotifier(true));

    expect(find.text('Criar o mês seguinte?'), findsOneWidget);
    await tester.tap(find.text('Criar 12/2026'));
    await tester.pumpAndSettle();

    expect(events.created, ['12/2026']);
    expect(find.text('Evento 12/2026 criado.'), findsOneWidget);
  });

  testWidgets('"Agora não" não cria nada', (tester) async {
    final events = _FakeEvents([_month(11, 'SETTLING')]);
    await _pump(tester, events, ValueNotifier(true));

    await tester.tap(find.text('Agora não'));
    await tester.pumpAndSettle();

    expect(events.created, isEmpty);
    expect(find.text('Criar o mês seguinte?'), findsNothing);
  });

  testWidgets('parcela já criou o mês seguinte: não pergunta', (tester) async {
    final events = _FakeEvents([_month(11, 'SETTLING'), _month(12, 'OPEN')]);
    await _pump(tester, events, ValueNotifier(true));

    expect(find.text('Criar o mês seguinte?'), findsNothing);
    expect(events.created, isEmpty);
  });

  testWidgets('tela recarrega e tira o botão do ar: pergunta mesmo assim',
      (tester) async {
    final visible = ValueNotifier(true);
    final events = _FakeEvents([_month(11, 'SETTLING')],
        onList: () => visible.value = false);
    await _pump(tester, events, visible);

    expect(find.text('abrir'), findsNothing);
    expect(find.text('Criar o mês seguinte?'), findsOneWidget);
    await tester.tap(find.text('Criar 12/2026'));
    await tester.pumpAndSettle();

    expect(events.created, ['12/2026']);
    expect(find.text('Evento 12/2026 criado.'), findsOneWidget);
  });
}
