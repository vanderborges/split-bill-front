import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/glass.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_state.dart';
import '../../../shared/widgets/money_text.dart';
import '../../events/services/events_repository.dart';
import '../../events/widgets/event_picker_field.dart' show EventStatusBadge;
import '../../expenses/services/expenses_repository.dart';
import '../../expenses/pages/expenses_page.dart';
import '../models/dashboard_group_balance_model.dart';
import '../services/dashboard_repository.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balancesAsync = ref.watch(dashboardGroupBalancesProvider);

    return AppScaffold(
      scrollsBehindTopBar: true,
      // Nome do app no lugar de "Início", maior que o padrão (26 pt).
      title: 'DividiAí',
      titleFontSize: 26,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg + topBarInset(context),
            AppSpacing.lg,
            AppSpacing.lg + bottomBarInset(context)),
        children: [
          Text(
            'Bora dividir uma conta?',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Cor lisa (flat), a mesma do "Fechar evento" e do "+".
          Material(
            color: Theme.of(context).colorScheme.primary,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              customBorder: const StadiumBorder(),
              // Abre o fluxo por cima da Home — ao salvar/cancelar a
              // pessoa continua no Início.
              onTap: () => openNewExpenseFlow(context, ref),
              child: SizedBox(
                height: 52,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add,
                        color: Theme.of(context).colorScheme.onPrimary),
                    const SizedBox(width: 8),
                    Text(
                      'Nova despesa',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Saldo por grupo',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Mostrando apenas os grupos em que você participa.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          balancesAsync.when(
            data: (balances) => _BalancesContent(balances: balances),
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: LoadingState(),
            ),
            error: (_, __) => ErrorState(
              message: 'Não foi possível carregar seus saldos.',
              onRetry: () => ref.invalidate(dashboardGroupBalancesProvider),
            ),
          ),
        ],
      ),
    );
  }
}

class _BalancesContent extends ConsumerWidget {
  const _BalancesContent({required this.balances});

  final List<DashboardGroupBalanceModel> balances;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (balances.isEmpty) {
      return const EmptyState(
        icon: Icons.groups_outlined,
        title: 'Você ainda não participa de grupos.',
        message: 'Crie ou entre em um grupo para começar a dividir despesas.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: balances
          .map((groupBalance) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _GroupCard(groupBalance: groupBalance),
              ))
          .toList(),
    );
  }
}

void _openEventExpenses(
  BuildContext context,
  WidgetRef ref,
  String groupId,
  String eventId,
) {
  selectEvent(ref, groupId: groupId, eventId: eventId);
  ref.invalidate(selectedEventProvider);
  ref.invalidate(selectedEventExpensesProvider);
  context.go('/expenses');
}

/// Grupo como cartão expansível: um grupo pode ter mais de um evento em
/// aberto ao mesmo tempo (ex.: dois meses, ou um mês + um avulso) — somar
/// tudo num único saldo escondia o que estava acontecendo em cada evento.
/// Aqui cada evento com despesa da pessoa aparece com o próprio saldo.
class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.groupBalance});

  final DashboardGroupBalanceModel groupBalance;

  @override
  Widget build(BuildContext context) {
    final events = groupBalance.events;

    if (events.isEmpty) {
      // Grupo sem evento: tocar leva pra tela de Eventos já nesse grupo,
      // onde dá pra cadastrar o primeiro.
      return Card(
        child: Consumer(
          builder: (context, ref, _) => ListTile(
            leading: const Icon(Icons.groups_outlined),
            title: Text(groupBalance.groupName),
            subtitle: const Text('Sem despesas em eventos abertos.'),
            onTap: () {
              selectEvent(ref, groupId: groupBalance.groupId);
              context.go('/events');
            },
          ),
        ),
      );
    }

    if (events.length == 1) {
      return Card(
        child: Consumer(
          builder: (context, ref, _) => ListTile(
            leading: const Icon(Icons.groups_outlined),
            title: Text(groupBalance.groupName),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.xs),
                // Evento único do grupo: sem a pílula de status.
                _EventNameWithStatus(events.first, showStatus: false),
                const SizedBox(height: AppSpacing.xs),
                Text(_balanceText(events.first)),
              ],
            ),
            trailing: MoneyText(
              events.first.balance,
              colorBySign: true,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            onTap: () => _openEventExpenses(
                context, ref, groupBalance.groupId, events.first.eventId),
          ),
        ),
      );
    }

    final total = events.fold<double>(0, (sum, event) => sum + event.balance);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: const Icon(Icons.groups_outlined),
        title: Text(groupBalance.groupName),
        subtitle: Text('${events.length} eventos em aberto'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MoneyText(
              total,
              colorBySign: true,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Icon(Icons.expand_more),
          ],
        ),
        children: events
            .map((event) => Consumer(
                  builder: (context, ref, _) => ListTile(
                    title: _EventNameWithStatus(event),
                    subtitle: Text(_balanceText(event)),
                    trailing: MoneyText(event.balance, colorBySign: true),
                    onTap: () => _openEventExpenses(
                        context, ref, groupBalance.groupId, event.eventId),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

/// Nome do evento com a pílula de status ao lado (mesmas cores do seletor
/// de evento e da tela de Eventos).
class _EventNameWithStatus extends StatelessWidget {
  const _EventNameWithStatus(this.event, {this.showStatus = true});

  final DashboardEventBalanceModel event;
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        Text(event.eventName),
        if (showStatus) EventStatusBadge(event.eventStatus),
      ],
    );
  }
}

String _balanceText(DashboardEventBalanceModel event) {
  return event.balance < 0
      ? 'Você tem a pagar'
      : event.balance > 0
          ? 'Você tem a receber'
          : 'Sem saldo em aberto';
}
