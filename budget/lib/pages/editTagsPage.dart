import 'package:budget/colors.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/functions.dart';
import 'package:budget/pages/addTagPage.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/fab.dart';
import 'package:budget/widgets/fadeIn.dart';
import 'package:budget/widgets/globalSnackbar.dart';
import 'package:budget/widgets/noResults.dart';
import 'package:budget/widgets/openBottomSheet.dart';
import 'package:budget/widgets/openPopup.dart';
import 'package:budget/widgets/openSnackbar.dart';
import 'package:budget/widgets/framework/pageFramework.dart';
import 'package:budget/widgets/textInput.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart' hide SliverReorderableList;
import 'package:flutter/services.dart' hide TextInput;
import 'package:budget/widgets/editRowEntry.dart';
import 'package:budget/modified/reorderable_list.dart';

class EditTagsPage extends StatefulWidget {
  EditTagsPage({
    Key? key,
  }) : super(key: key);

  @override
  _EditTagsPageState createState() => _EditTagsPageState();
}

class _EditTagsPageState extends State<EditTagsPage> {
  bool dragDownToDismissEnabled = true;
  int currentReorder = -1;
  String searchValue = "";

  void openAddTag({Tag? tag}) {
    openBottomSheet(
      context,
      popupWithKeyboard: true,
      AddTagPage(tag: tag),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (searchValue != "") {
          setState(() {
            searchValue = "";
          });
          return false;
        } else {
          return true;
        }
      },
      child: PageFramework(
        horizontalPaddingConstrained: true,
        dragDownToDismiss: true,
        dragDownToDismissEnabled: dragDownToDismissEnabled,
        title: "tags".tr(),
        scrollToTopButton: true,
        floatingActionButton: AnimateFABDelayed(
          fab: AddFAB(
            tooltip: "add-tag".tr(),
            onTap: () => openAddTag(),
          ),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsetsDirectional.only(bottom: 8.0),
              child: TextInput(
                labelText: "search-tags-placeholder".tr(),
                icon: appStateSettings["outlinedIcons"]
                    ? Icons.search_outlined
                    : Icons.search_rounded,
                onSubmitted: (value) {
                  setState(() {
                    searchValue = value;
                  });
                },
                onChanged: (value) {
                  setState(() {
                    searchValue = value;
                  });
                },
                autoFocus: false,
              ),
            ),
          ),
          StreamBuilder<List<Tag>>(
            stream: database.watchAllTags(
                searchFor: searchValue == "" ? null : searchValue),
            builder: (context, snapshot) {
              List<Tag> tags = snapshot.data ?? [];
              if (snapshot.hasData && tags.length <= 0) {
                return SliverToBoxAdapter(
                  child: NoResults(
                    message: "no-tags-found".tr(),
                  ),
                );
              }
              if (snapshot.hasData && tags.length > 0) {
                return SliverReorderableList(
                  onReorderStart: (index) {
                    HapticFeedback.heavyImpact();
                    setState(() {
                      dragDownToDismissEnabled = false;
                      currentReorder = index;
                    });
                  },
                  onReorderEnd: (_) {
                    setState(() {
                      dragDownToDismissEnabled = true;
                      currentReorder = -1;
                    });
                  },
                  itemBuilder: (context, index) {
                    Tag tag = tags[index];
                    return EditRowEntry(
                      canReorder: searchValue == "" && tags.length != 1,
                      onTap: () => openAddTag(tag: tag),
                      padding: EdgeInsetsDirectional.symmetric(
                          vertical: 7,
                          horizontal:
                              getPlatform() == PlatformOS.isIOS ? 17 : 7),
                      currentReorder:
                          currentReorder != -1 && currentReorder != index,
                      index: index,
                      content: Row(
                        children: [
                          SizedBox(width: 3),
                          TagColorDot(tag: tag, size: 22),
                          SizedBox(width: 15),
                          Expanded(
                            child: TextFont(
                              text: tag.name,
                              fontSize: 16,
                              maxLines: 3,
                            ),
                          ),
                        ],
                      ),
                      onDelete: () async {
                        return (await deleteTagPopup(
                              context,
                              tag: tag,
                              routesToPopAfterDelete:
                                  RoutesToPopAfterDelete.None,
                            )) ==
                            DeletePopupAction.Delete;
                      },
                      openPage: Container(),
                      key: ValueKey(tag.tagPk),
                    );
                  },
                  itemCount: tags.length,
                  onReorder: (_intPrevious, _intNew) async {
                    Tag oldTag = tags[_intPrevious];
                    if (_intNew > _intPrevious) {
                      await database.moveTag(
                          oldTag.tagPk, _intNew - 1, oldTag.order);
                    } else {
                      await database.moveTag(
                          oldTag.tagPk, _intNew, oldTag.order);
                    }
                    return true;
                  },
                );
              }
              return SliverToBoxAdapter(
                child: Container(),
              );
            },
          ),
          SliverToBoxAdapter(
            child: SizedBox(height: 85),
          ),
        ],
      ),
    );
  }
}

class TagColorDot extends StatelessWidget {
  const TagColorDot({required this.tag, this.size = 12, super.key});
  final Tag tag;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: HexColor(tag.colour,
            defaultColor: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

Future<DeletePopupAction?> deleteTagPopup(
  BuildContext context, {
  required Tag tag,
  required RoutesToPopAfterDelete routesToPopAfterDelete,
}) async {
  int numberOfTransactions =
      (await database.getAllTransactionsWithTag(tag.tagPk)).length;
  DeletePopupAction? action = await openDeletePopup(
    context,
    title: "delete-tag-question".tr(),
    subtitle: tag.name,
    description: numberOfTransactions > 0
        ? "delete-tag-description"
            .tr(namedArgs: {"count": numberOfTransactions.toString()})
        : null,
  );
  if (action == DeletePopupAction.Delete) {
    if (routesToPopAfterDelete == RoutesToPopAfterDelete.All) {
      popAllRoutes(context);
    } else if (routesToPopAfterDelete == RoutesToPopAfterDelete.One) {
      popRoute(context);
    }
    openLoadingPopupTryCatch(() async {
      await database.deleteTag(tag);
      openSnackbar(
        SnackbarMessage(
          title: "deleted-tag".tr(),
          icon: appStateSettings["outlinedIcons"]
              ? Icons.delete_outlined
              : Icons.delete_rounded,
          description: tag.name,
        ),
      );
    });
  }
  return action;
}
