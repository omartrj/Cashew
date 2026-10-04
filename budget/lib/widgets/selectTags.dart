import 'package:budget/colors.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/widgets/navigationSidebar.dart';
import 'package:budget/pages/addTagPage.dart';
import 'package:budget/pages/addTransactionPage.dart';
import 'package:budget/pages/editTagsPage.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/openBottomSheet.dart';
import 'package:budget/widgets/selectChips.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Multiple selection of the tags of a transaction
class SelectTags extends StatefulWidget {
  const SelectTags({
    required this.setSelectedTags,
    required this.selectedTagPks,
    this.extraHorizontalPadding,
    this.wrapped,
    this.horizontalBreak = false,
    this.hideIfNoTags = false,
    super.key,
  });
  final Function(List<String>) setSelectedTags;
  final List<String> selectedTagPks;
  final double? extraHorizontalPadding;
  final bool? wrapped;
  final bool horizontalBreak;
  final bool hideIfNoTags;

  @override
  State<SelectTags> createState() => _SelectTagsState();
}

class _SelectTagsState extends State<SelectTags> {
  // Kept locally too, because in a popup the parent does not rebuild this
  late List<String> selectedTagPks = [...widget.selectedTagPks];

  @override
  void didUpdateWidget(covariant SelectTags oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (listEquals(selectedTagPks, widget.selectedTagPks) == false) {
      setState(() {
        selectedTagPks = [...widget.selectedTagPks];
      });
    }
  }

  void toggleTag(String tagPk) {
    setState(() {
      if (selectedTagPks.contains(tagPk)) {
        selectedTagPks.remove(tagPk);
      } else {
        selectedTagPks.add(tagPk);
      }
    });
    widget.setSelectedTags([...selectedTagPks]);
  }

  Future addTag() async {
    dynamic result = await openBottomSheet(
      context,
      popupWithKeyboard: true,
      AddTagPage(),
    );
    // Select the tag that was just created
    if (result is Tag && selectedTagPks.contains(result.tagPk) == false) {
      toggleTag(result.tagPk);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Tag>>(
      stream: database.watchAllTags(),
      builder: (context, snapshot) {
        if (snapshot.hasData == false) return Container();
        List<Tag> tags = snapshot.data!;
        if (tags.isEmpty && widget.hideIfNoTags) return Container();
        return HorizontalBreakAbove(
          enabled: enableDoubleColumn(context) && widget.horizontalBreak,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(top: 5),
            child: SelectChips(
              wrapped: widget.wrapped ?? enableDoubleColumn(context),
              extraHorizontalPadding: widget.extraHorizontalPadding,
              extraWidgetBefore: tags.isEmpty
                  ? Padding(
                      padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: 5),
                      child: Icon(
                        appStateSettings["outlinedIcons"]
                            ? Icons.sell_outlined
                            : Icons.sell_rounded,
                        color: getColor(context, "textLight"),
                      ),
                    )
                  : null,
              extraWidgetAfter: SelectChipsAddButtonExtraWidget(
                openPage: null,
                onTap: addTag,
              ),
              items: tags,
              getLabel: (Tag tag) => tag.name,
              getAvatar: (Tag tag) => TagColorDot(tag: tag),
              onSelected: (Tag tag) => toggleTag(tag.tagPk),
              getSelected: (Tag tag) => selectedTagPks.contains(tag.tagPk),
              onLongPress: (Tag tag) {
                openBottomSheet(
                  context,
                  popupWithKeyboard: true,
                  AddTagPage(tag: tag),
                );
              },
              getCustomBorderColor: (Tag tag) {
                return dynamicPastel(
                  context,
                  lightenPastel(
                    HexColor(
                      tag.colour,
                      defaultColor: Theme.of(context).colorScheme.primary,
                    ),
                    amount: 0.3,
                  ),
                  amount: 0.4,
                );
              },
            ),
          ),
        );
      },
    );
  }
}
