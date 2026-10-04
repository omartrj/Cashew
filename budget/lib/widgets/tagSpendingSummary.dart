import 'dart:math';

import 'package:budget/colors.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/functions.dart';
import 'package:budget/pages/transactionFilters.dart';
import 'package:budget/pages/transactionsSearchPage.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/openBottomSheet.dart';
import 'package:budget/widgets/tappable.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Spending of each tag for the period shown on the all spending page
class TagSpendingSummary extends StatelessWidget {
  const TagSpendingSummary({
    required this.walletPks,
    required this.isIncome,
    required this.isAllSpending,
    required this.cycleSettingsExtension,
    required this.totalSpent,
    required this.useHorizontalPaddingConstrained,
    this.selectedDateTimeRange,
    this.searchFilters,
    this.getDateTimeRangeForPassedSearchFilters,
    super.key,
  });

  final List<String>? walletPks;
  final bool isIncome;
  final bool isAllSpending;
  final String cycleSettingsExtension;
  // Total of the period, the percentages are relative to it
  final double totalSpent;
  final bool useHorizontalPaddingConstrained;
  final DateTimeRange? selectedDateTimeRange;
  final SearchFilters? searchFilters;
  final DateTimeRange? Function()? getDateTimeRangeForPassedSearchFilters;

  @override
  Widget build(BuildContext context) {
    List<Tag> allTags = Provider.of<AllTags>(context).list;
    if (allTags.isEmpty) return SizedBox.shrink();
    return StreamBuilder<List<TagWithTotal>>(
      stream: database.watchTotalSpentInEachTag(
        allWallets: Provider.of<AllWallets>(context),
        allTags: allTags,
        walletPks: walletPks,
        isIncome: isIncome,
        followCustomPeriodCycle: isAllSpending,
        cycleSettingsExtension: cycleSettingsExtension,
        forcedDateTimeRange: selectedDateTimeRange,
        searchFilters: searchFilters,
      ),
      builder: (context, snapshot) {
        List<TagWithTotal> tagTotals = snapshot.data ?? [];
        if (tagTotals.isEmpty) return SizedBox.shrink();
        return Padding(
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: getHorizontalPaddingConstrained(context,
                enabled: useHorizontalPaddingConstrained),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(
                    start: 20, end: 20, top: 15, bottom: 2),
                child: TextFont(
                  text: "tags".tr(),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.only(
                    start: 20, end: 20, bottom: 5),
                child: TextFont(
                  text: "tags-spending-description".tr(),
                  fontSize: 13,
                  maxLines: 3,
                  textColor: getColor(context, "textLight"),
                ),
              ),
              for (TagWithTotal tagTotal in tagTotals)
                TagSpendingEntry(
                  tagWithTotal: tagTotal,
                  totalSpent: totalSpent,
                  onTap: () {
                    pushRoute(
                      context,
                      TransactionsSearchPage(
                        initialFilters:
                            (searchFilters ?? SearchFilters()).copyWith(
                          dateTimeRange:
                              getDateTimeRangeForPassedSearchFilters?.call(),
                          walletPks: walletPks,
                          tagPks: [tagTotal.tagPk],
                          positiveCashFlow: isIncome,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class TagSpendingEntry extends StatelessWidget {
  const TagSpendingEntry({
    required this.tagWithTotal,
    required this.totalSpent,
    required this.onTap,
    super.key,
  });
  final TagWithTotal tagWithTotal;
  final double totalSpent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Tag tag = tagWithTotal.tag!;
    double tagSpent = tagWithTotal.total;
    double percentSpent =
        removeNaNAndInfinity((tagSpent / totalSpent).abs());
    Color tagColor =
        HexColor(tag.colour, defaultColor: Theme.of(context).colorScheme.primary);
    Color amountColor = tagSpent == 0
        ? getColor(context, "black")
        : tagSpent > 0
            ? getColor(context, "incomeAmount")
            : getColor(context, "expenseAmount");
    int transactionCount = tagWithTotal.transactionCount;
    return Tappable(
      onTap: onTap,
      color: Colors.transparent,
      borderRadius: 15,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
            start: 20, end: 25, top: 8, bottom: 8),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dynamicPastel(context, tagColor,
                    amountLight: 0.55, amountDark: 0.35),
              ),
              child: Icon(
                appStateSettings["outlinedIcons"]
                    ? Icons.sell_outlined
                    : Icons.sell_rounded,
                size: 22,
                color: dynamicPastel(context, tagColor,
                    inverse: true, amountLight: 0.1, amountDark: 0.1),
              ),
            ),
            SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFont(
                          text: tag.name,
                          fontSize: 17,
                          maxLines: 1,
                        ),
                      ),
                      SizedBox(width: 10),
                      if (tagSpent != 0)
                        Transform.translate(
                          offset: Offset(3, 0),
                          child: Transform.rotate(
                            angle: tagSpent >= 0 ? pi : 0,
                            child: Icon(
                              appStateSettings["outlinedIcons"]
                                  ? Icons.arrow_drop_down_outlined
                                  : Icons.arrow_drop_down_rounded,
                              color: amountColor,
                            ),
                          ),
                        ),
                      TextFont(
                        fontWeight: FontWeight.bold,
                        text: convertToMoney(
                            Provider.of<AllWallets>(context), tagSpent.abs()),
                        fontSize: 20,
                        textColor: amountColor,
                      ),
                    ],
                  ),
                  SizedBox(height: 1),
                  Row(
                    children: [
                      Expanded(
                        child: TextFont(
                          text: convertToPercent(percentSpent * 100,
                                  useLessThanZero: true) +
                              " " +
                              (tagSpent > 0
                                  ? "of-incoming".tr().toLowerCase()
                                  : "of-outgoing".tr().toLowerCase()),
                          fontSize: 14,
                          textColor: getColor(context, "textLight"),
                        ),
                      ),
                      TextFont(
                        text: transactionCount.toString() +
                            " " +
                            (transactionCount == 1
                                ? "transaction".tr().toLowerCase()
                                : "transactions".tr().toLowerCase()),
                        fontSize: 14,
                        textColor: getColor(context, "textLight"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
