import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:local_auth/auth_strings.dart';
import 'package:local_auth/local_auth.dart';
import 'package:potato_notes/data/dao/note_helper.dart';
import 'package:potato_notes/data/database.dart';
import 'package:potato_notes/data/model/list_content.dart';
import 'package:potato_notes/data/model/saved_image.dart';
import 'package:potato_notes/internal/providers.dart';
import 'package:potato_notes/internal/sync/image/image_service.dart';
import 'package:potato_notes/internal/sync/sync_routine.dart';
import 'package:potato_notes/routes/about_page.dart';
import 'package:potato_notes/routes/base_page.dart';
import 'package:potato_notes/routes/note_page.dart';
import 'package:potato_notes/widget/bottom_sheet_base.dart';
import 'package:potato_notes/widget/dismissible_route.dart';
import 'package:potato_notes/widget/list_tile_popup_menu_item.dart';
import 'package:potato_notes/widget/pass_challenge.dart';
import 'package:recase/recase.dart';
import 'package:uuid/uuid.dart';

import 'locale_strings.dart';

const int kMaxImageCount = 4;
const double kCardBorderRadius = 6;
const EdgeInsets kCardPadding = const EdgeInsets.all(4);

class Utils {
  static deleteNoteSafely(Note note) {
    ImageService.handleNoteDeletion(note);
    helper.deleteNote(note);
  }

  static handleNotePagePop(Note note) {
    ImageService.handleDeletes();
    helper.listNotes(ReturnMode.LOCAL).then((notes) => {
          SyncRoutine.syncNote(notes.firstWhere((local) => local.id == note.id))
        });
  }

  static Future<dynamic> showPassChallengeSheet(BuildContext context) async {
    return await showNotesModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => PassChallenge(
        editMode: false,
        onChallengeSuccess: () => Navigator.pop(context, true),
        onSave: null,
      ),
    );
  }

  static Future<bool> showBiometricPrompt() async {
    return await LocalAuthentication().authenticateWithBiometrics(
      localizedReason: "",
      stickyAuth: true,
      androidAuthStrings: AndroidAuthMessages(
        signInTitle: LocaleStrings.common.biometricsPrompt,
        fingerprintHint: "",
        cancelButton: LocaleStrings.common.cancel,
      ),
    );
  }

  static Future<dynamic> showNotesModalBottomSheet({
    @required BuildContext context,
    @required WidgetBuilder builder,
    Color backgroundColor,
    double elevation,
    ShapeBorder shape,
    Clip clipBehavior,
    Color barrierColor,
    bool isScrollControlled = false,
    bool useRootNavigator = false,
    bool isDismissible = true,
    bool enableDrag = true,
  }) async {
    return await showModalBottomSheet(
      context: context,
      builder: (context) => BottomSheetBase(
        child: builder(context),
        backgroundColor: backgroundColor,
        elevation: elevation,
        shape: shape,
        clipBehavior: clipBehavior,
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: null,
      clipBehavior: Clip.none,
      barrierColor: barrierColor,
      isScrollControlled: isScrollControlled,
      useRootNavigator: useRootNavigator,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
    );
  }

  static List<ListTilePopupMenuItem<String>> popupItems(BuildContext context) {
    return [
      ListTilePopupMenuItem(
        leading: Icon(Icons.push_pin_outlined),
        title: Text(LocaleStrings.mainPage.selectionBarPin),
        value: 'pin',
      ),
      ListTilePopupMenuItem(
        leading: Icon(Icons.share_outlined),
        title: Text(LocaleStrings.mainPage.selectionBarShare),
        value: 'share',
      ),
    ];
  }

  static void showFabMenu(
      BuildContext context, RenderBox fabBox, List<Widget> items) {
    Size fabSize = fabBox.size;
    Offset fabPosition = fabBox.localToGlobal(Offset(0, 0));
    Size screenSize = MediaQuery.of(context).size;

    bool isOnTop = fabPosition.dy < screenSize.height / 2;
    bool isOnLeft = fabPosition.dx < screenSize.width / 2;

    double top = isOnTop ? fabPosition.dy : null;
    double left = isOnLeft ? fabPosition.dx : null;
    double right =
        !isOnTop ? screenSize.width - (fabPosition.dx + fabSize.width) : null;
    double bottom = !isOnLeft
        ? screenSize.height - (fabPosition.dy + fabSize.height)
        : null;

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, anim, secAnim) {
          return Stack(
            children: <Widget>[
              GestureDetector(
                onTapDown: (details) => Navigator.pop(context),
                child: SizedBox.expand(
                  child: AnimatedBuilder(
                    animation: anim,
                    builder: (context, _) => DecoratedBox(
                      decoration: BoxDecoration(
                        color: ColorTween(
                          begin: Colors.transparent,
                          end: Colors.black38,
                        ).animate(anim).value,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: top,
                left: left,
                right: right,
                bottom: bottom,
                child: Hero(
                  tag: "fabMenu",
                  child: Material(
                    elevation: 6,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(kCardBorderRadius),
                    ),
                    child: SizedBox(
                      width: 250,
                      child: ListView(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.all(0),
                        reverse: true,
                        children: isOnTop ? items.reversed.toList() : items,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        opaque: false,
        barrierDismissible: true,
      ),
    );
  }

  static String generateId() {
    return Uuid().v4();
  }

  static String getNameFromMode(ReturnMode mode, {int tagIndex = 0}) {
    switch (mode) {
      case ReturnMode.NORMAL:
        return LocaleStrings.mainPage.titleHome;
      case ReturnMode.ARCHIVE:
        return LocaleStrings.mainPage.titleArchive;
      case ReturnMode.TRASH:
        return LocaleStrings.mainPage.titleTrash;
      case ReturnMode.FAVOURITES:
        return LocaleStrings.mainPage.titleFavourites;
      case ReturnMode.TAG:
        if (prefs.tags.isNotEmpty) {
          return prefs.tags[tagIndex].name;
        } else {
          return LocaleStrings.mainPage.titleTag;
        }
        break;
      case ReturnMode.ALL:
      default:
        return LocaleStrings.mainPage.titleAll;
    }
  }

  static get defaultAccent => Color(0xFF66BB6A);

  static Future<void> deleteNotes({
    @required BuildContext context,
    @required List<Note> notes,
    @required String reason,
    bool archive = false,
  }) async {
    for (Note note in notes) {
      if (archive) {
        await helper.saveNote(
            note.markChanged().copyWith(deleted: false, archived: true));
      } else {
        await helper.saveNote(
            note.markChanged().copyWith(deleted: true, archived: false));
      }
    }

    List<Note> backupNotes = List.from(notes);

    BasePage.of(context)?.hideCurrentSnackBar();
    BasePage.of(context)?.showSnackBar(
      SnackBar(
        content: Text(reason),
        action: SnackBarAction(
          label: LocaleStrings.common.undo,
          onPressed: () async {
            for (Note note in backupNotes) {
              await helper
                  .saveNote(note.copyWith(deleted: false, archived: false));
            }
          },
        ),
      ),
    );
  }

  static Future<void> restoreNotes({
    @required BuildContext context,
    @required List<Note> notes,
    @required String reason,
    bool archive = false,
  }) async {
    for (Note note in notes) {
      await helper.saveNote(
          note.markChanged().copyWith(deleted: false, archived: false));
    }

    List<Note> backupNotes = List.from(notes);

    BasePage.of(context)?.hideCurrentSnackBar();
    BasePage.of(context)?.showSnackBar(
      SnackBar(
        content: Text(reason),
        action: SnackBarAction(
          label: LocaleStrings.common.undo,
          onPressed: () async {
            for (Note note in backupNotes) {
              if (archive) {
                await helper
                    .saveNote(note.copyWith(deleted: false, archived: true));
              } else {
                await helper
                    .saveNote(note.copyWith(deleted: true, archived: false));
              }
            }
          },
        ),
      ),
    );
  }

  static List<ContributorInfo> get contributors => [
        ContributorInfo(
          name: "Davide Bianco",
          role: LocaleStrings.aboutPage.contributorsHrX,
          avatarUrl: "https://avatars.githubusercontent.com/u/29352339",
          socialLinks: [
            SocialLink(SocialLinkType.GITHUB, "HrX03"),
            SocialLink(SocialLinkType.INSTAGRAM, "b_b_biancoboi"),
            SocialLink(SocialLinkType.TWITTER, "HrX2003"),
          ],
        ),
        ContributorInfo(
          name: "Bas Wieringa (broodrooster)",
          role: LocaleStrings.aboutPage.contributorsBas,
          avatarUrl: "https://avatars.githubusercontent.com/u/31385368",
          socialLinks: [
            SocialLink(SocialLinkType.GITHUB, "broodroosterdev"),
          ],
        ),
        ContributorInfo(
          name: "Nico Franke",
          role: LocaleStrings.aboutPage.contributorsNico,
          avatarUrl: "https://avatars.githubusercontent.com/u/23036430",
          socialLinks: [
            SocialLink(SocialLinkType.GITHUB, "ZerNico"),
            SocialLink(SocialLinkType.INSTAGRAM, "z3rnico"),
            SocialLink(SocialLinkType.TWITTER, "Z3rNico"),
          ],
        ),
        ContributorInfo(
          name: "SphericalKat",
          role: LocaleStrings.aboutPage.contributorsKat,
          avatarUrl: "https://avatars.githubusercontent.com/u/31761843",
          socialLinks: [
            SocialLink(SocialLinkType.GITHUB, "ATechnoHazard"),
          ],
        ),
        ContributorInfo(
          name: "Rohit K.Parida",
          role: LocaleStrings.aboutPage.contributorsRohit,
          avatarUrl: "https://avatars.githubusercontent.com/u/18437518",
          socialLinks: [
            SocialLink(SocialLinkType.TWITTER, "paridadesigns"),
          ],
        ),
        ContributorInfo(
          name: "RshBfn",
          role: LocaleStrings.aboutPage.contributorsRshBfn,
          avatarUrl:
              "https://pbs.twimg.com/profile_images/1282395593646604288/Rkxny-Fi.jpg",
          socialLinks: [
            SocialLink(SocialLinkType.TWITTER, "RshBfn"),
          ],
        ),
      ];

  static Future<dynamic> showSecondaryRoute(
    BuildContext context,
    Widget route, {
    bool allowGestures = true,
    bool pushImmediate = false,
  }) async {
    return Navigator.of(context).push(
      DismissiblePageRoute(
        builder: (context) => route,
        allowGestures: allowGestures,
        pushImmediate: pushImmediate,
      ),
    );
  }

  static void newNote(BuildContext context) async {
    int currentLength = (await helper.listNotes(ReturnMode.NORMAL)).length;

    await Utils.showSecondaryRoute(
      context,
      NotePage(),
    );

    List<Note> notes = await helper.listNotes(ReturnMode.NORMAL);
    int newLength = notes.length;

    if (newLength > currentLength) {
      Note lastNote = notes.last;

      if (lastNote.title.isEmpty &&
          lastNote.content.isEmpty &&
          lastNote.listContent.isEmpty &&
          lastNote.images.isEmpty &&
          lastNote.reminders.isEmpty) {
        Utils.deleteNotes(
          context: context,
          notes: [lastNote],
          reason: LocaleStrings.mainPage.deletedEmptyNote,
        );
      }
    }
  }

  static void newImage(BuildContext context, ImageSource source,
      {bool shouldPop = false}) async {
    Note note = NoteX.emptyNote;
    PickedFile image = await ImagePicker().getImage(source: source);

    if (image != null) {
      SavedImage savedImage =
          await ImageService.prepareLocally(File(image.path));
      note.images.add(savedImage);

      if (shouldPop) Navigator.pop(context);
      note = note.copyWith(id: Utils.generateId());

      Utils.showSecondaryRoute(
        context,
        NotePage(
          note: note,
        ),
      );

      helper.saveNote(note.markChanged());
    }
  }

  static void newList(BuildContext context) {
    Utils.showSecondaryRoute(
      context,
      NotePage(
        openWithList: true,
      ),
    );
  }

  static void newDrawing(BuildContext context) {
    Utils.showSecondaryRoute(
      context,
      NotePage(
        openWithDrawing: true,
      ),
    );
  }

  static String get defaultApiUrl => "https://sync.potatoproject.co/api/v2";
}

extension NoteX on Note {
  static Note get emptyNote => Note(
        id: null,
        title: "",
        content: "",
        styleJson: [],
        starred: false,
        creationDate: DateTime.now(),
        lastModifyDate: DateTime.now(),
        color: 0,
        images: [],
        list: false,
        listContent: [],
        reminders: [],
        tags: [],
        hideContent: false,
        lockNote: false,
        usesBiometrics: false,
        deleted: false,
        archived: false,
        synced: false,
      );

  static Note fromSyncMap(Map<String, dynamic> syncMap) {
    Map<String, dynamic> newMap = Map();
    syncMap.forEach((key, value) {
      var newValue = value;
      var newKey = ReCase(key).camelCase;
      switch (key) {
        case "style_json":
          {
            var map = json.decode(value);
            List<int> data = List<int>.from(map.map((i) => i as int)).toList();
            newValue = data;
            break;
          }
        case "images":
          {
            List<dynamic> list = json.decode(value);
            List<SavedImage> images =
                list.map((i) => SavedImage.fromJson(i)).toList();
            newValue = images;
            break;
          }
        case "list_content":
          {
            var map = json.decode(value);
            List<ListItem> content =
                List<ListItem>.from(map.map((i) => ListItem.fromJson(i)))
                    .toList();
            newValue = content;
            break;
          }
        case "reminders":
          {
            var map = json.decode(value);
            List<DateTime> reminders =
                List<DateTime>.from(map.map((i) => DateTime.parse(i))).toList();
            newValue = reminders;
            break;
          }
        case "tags":
          {
            var map = json.decode(value);
            List<String> tagIds = List<String>.from(map).toList();
            newValue = tagIds;
          }
      }
      if (key == "note_id") {
        newKey = "id";
      }
      newMap.putIfAbsent(newKey, () => newValue);
    });
    return Note.fromJson(newMap);
  }

  Map<String, dynamic> toSyncMap() {
    var originalMap = this.toJson();
    Map<String, dynamic> newMap = Map();
    originalMap.forEach((key, value) {
      var newValue = value;
      var newKey = ReCase(key).snakeCase;
      switch (key) {
        case "styleJson":
          {
            var style = value as List<int>;
            newValue = json.encode(style);
            break;
          }
        case "images":
          {
            var images = value as List<SavedImage>;
            newValue = json.encode(images);
            break;
          }
        case "listContent":
          {
            var listContent = value as List<ListItem>;
            newValue = json.encode(listContent);
            break;
          }
        case "reminders":
          {
            var reminders = value as List<DateTime>;
            newValue = json.encode(reminders);
            break;
          }
        case "tags":
          {
            var tags = value as List<String>;
            newValue = json.encode(tags);
            break;
          }
      }
      if (key == "id") {
        newKey = "note_id";
      }
      newMap.putIfAbsent(newKey, () => newValue);
    });
    return newMap;
  }

  Note markChanged() {
    return copyWith(synced: false, lastModifyDate: DateTime.now());
  }
}

extension TagX on Tag {
  Tag markChanged() {
    return copyWith(lastModifyDate: DateTime.now());
  }
}

extension UriX on Uri {
  ImageProvider toImageProvider() {
    if (data != null) {
      return MemoryImage(data.contentAsBytes());
    } else if (scheme.startsWith("http") || scheme.startsWith("blob")) {
      return CachedNetworkImageProvider(toString());
    } else {
      return FileImage(File(path));
    }
  }
}
