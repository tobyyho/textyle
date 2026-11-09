import 'package:web/web.dart' as web;
import 'm11_saved_association.dart';

String? m11ReadSavedAssociation() =>
    web.window.localStorage.getItem(m11SavedAssociationsStorageKey) ??
    web.window.localStorage.getItem(m11SavedAssociationStorageKey);
