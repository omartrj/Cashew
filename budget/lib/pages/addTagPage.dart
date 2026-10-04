import 'package:budget/colors.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/functions.dart';
import 'package:budget/pages/editTagsPage.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/button.dart';
import 'package:budget/widgets/framework/popupFramework.dart';
import 'package:budget/pages/settingsPage.dart';
import 'package:budget/widgets/globalSnackbar.dart';
import 'package:budget/widgets/openBottomSheet.dart';
import 'package:budget/widgets/openPopup.dart';
import 'package:budget/widgets/openSnackbar.dart';
import 'package:budget/widgets/selectColor.dart';
import 'package:budget/widgets/textInput.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Opened in a bottom sheet, pops with the saved Tag
class AddTagPage extends StatefulWidget {
  AddTagPage({
    Key? key,
    this.tag,
  }) : super(key: key);

  //When a Tag is passed in, we are editing that Tag
  final Tag? tag;

  @override
  _AddTagPageState createState() => _AddTagPageState();
}

class _AddTagPageState extends State<AddTagPage> {
  late String selectedName = widget.tag?.name ?? "";
  late Color? selectedColor =
      widget.tag?.colour == null ? null : HexColor(widget.tag?.colour);
  late FocusNode _focusNode;

  bool get canAddTag => selectedName.trim() != "";

  Future addTag() async {
    Tag? tagWithSameName =
        await database.getTagInstanceGivenNameTrim(selectedName);
    if (tagWithSameName != null &&
        tagWithSameName.tagPk != widget.tag?.tagPk) {
      openSnackbar(
        SnackbarMessage(
          title: "tag-already-exists".tr(),
          description: tagWithSameName.name,
          icon: appStateSettings["outlinedIcons"]
              ? Icons.warning_outlined
              : Icons.warning_rounded,
        ),
      );
      return;
    }
    Tag tag = Tag(
      // Generate the key here so the new tag can be returned and selected
      tagPk: widget.tag?.tagPk ?? uuid.v4(),
      name: selectedName.trim(),
      colour: toHexString(selectedColor),
      dateCreated: widget.tag?.dateCreated ?? DateTime.now(),
      dateTimeModified: null,
      order: widget.tag?.order ?? await database.getAmountOfTags(),
    );
    await database.createOrUpdateTag(tag);
    savingHapticFeedback();
    popRoute(context, tag);
  }

  @override
  void initState() {
    super.initState();
    _focusNode = new FocusNode();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopupFramework(
      title: widget.tag == null ? "add-tag".tr() : "edit-tag".tr(),
      outsideExtraWidget: widget.tag == null
          ? null
          : IconButton(
              iconSize: 25,
              padding: EdgeInsetsDirectional.all(
                  getPlatform() == PlatformOS.isIOS ? 15 : 20),
              icon: Icon(
                appStateSettings["outlinedIcons"]
                    ? Icons.delete_outlined
                    : Icons.delete_rounded,
              ),
              onPressed: () {
                deleteTagPopup(
                  context,
                  tag: widget.tag!,
                  routesToPopAfterDelete: RoutesToPopAfterDelete.One,
                );
              },
            ),
      child: Column(
        children: [
          TextInput(
            labelText: "name-placeholder".tr(),
            bubbly: false,
            initialValue: selectedName,
            onChanged: (text) {
              setState(() {
                selectedName = text;
              });
            },
            onSubmitted: (_) {
              if (canAddTag) addTag();
            },
            padding: EdgeInsetsDirectional.only(start: 7, end: 7),
            fontSize: getIsFullScreen(context) ? 25 : 23,
            fontWeight: FontWeight.bold,
            topContentPadding: 0,
            focusNode: _focusNode,
            autoFocus: kIsWeb && getIsFullScreen(context),
          ),
          SizedBox(height: 17),
          Container(
            height: 65,
            child: SelectColor(
              horizontalList: true,
              selectedColor: selectedColor,
              setSelectedColor: (Color? color) {
                setState(() {
                  selectedColor = color;
                });
              },
            ),
          ),
          SizedBox(height: 17),
          Button(
            label: widget.tag == null ? "add-tag".tr() : "save-changes".tr(),
            width: MediaQuery.sizeOf(context).width,
            onTap: () async {
              if (canAddTag) await addTag();
            },
            color: canAddTag ? null : Colors.grey,
          ),
        ],
      ),
    );
  }
}
