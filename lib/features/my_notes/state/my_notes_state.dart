import 'package:flutter/material.dart';

enum MyNotesView { list, template, editor }

enum MyNotesFilter {
  all('所有笔记'),
  recent('最近'),
  favorite('收藏'),
  unarchived('未归档');

  const MyNotesFilter(this.label);

  final String label;
}

enum NotePaperType {
  staff(0, '五线谱'),
  notebook(1, '笔记本'),
  blank(2, '白纸');

  const NotePaperType(this.value, this.label);

  final int value;
  final String label;

  static NotePaperType fromValue(dynamic value) {
    final intValue = int.tryParse(value?.toString() ?? '');
    for (final item in values) {
      if (item.value == intValue) {
        return item;
      }
    }
    return blank;
  }
}

class NoteCategoryItem {
  const NoteCategoryItem({
    required this.id,
    required this.name,
    required this.count,
  });

  final int id;
  final String name;
  final int count;

  NoteCategoryItem copyWith({int? id, String? name, int? count}) {
    return NoteCategoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      count: count ?? this.count,
    );
  }
}

class NoteEntry {
  const NoteEntry({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.imageUrl,
    required this.createdAt,
    required this.paperType,
    this.isFavorite = false,
  });

  final int id;
  final int categoryId;
  final String title;
  final String imageUrl;
  final DateTime createdAt;
  final NotePaperType paperType;
  final bool isFavorite;

  String get dateLabel {
    final month = createdAt.month.toString().padLeft(2, '0');
    final day = createdAt.day.toString().padLeft(2, '0');
    return '${createdAt.year}-$month-$day';
  }

  NoteEntry copyWith({
    int? id,
    int? categoryId,
    String? title,
    String? imageUrl,
    DateTime? createdAt,
    NotePaperType? paperType,
    bool? isFavorite,
  }) {
    return NoteEntry(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      title: title ?? this.title,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      paperType: paperType ?? this.paperType,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}

class NoteStroke {
  const NoteStroke({
    required this.color,
    required this.width,
    required this.points,
  });

  final Color color;
  final double width;
  final List<Offset> points;
}

class MyNotesState {
  const MyNotesState({
    this.loading = false,
    this.busy = false,
    this.errorMessage,
    this.view = MyNotesView.list,
    this.categories = const <NoteCategoryItem>[],
    this.selectedCategoryId = 0,
    this.activeFilter = MyNotesFilter.all,
    this.notes = const <NoteEntry>[],
    this.paperType = NotePaperType.blank,
    this.draftTitle = '笔记名称',
    this.strokes = const <NoteStroke>[],
    this.selectedColor = const Color(0xFF2A2A2A),
    this.strokeWidth = 12,
    this.editingNote,
    this.editorBackgroundImageUrl,
  });

  final bool loading;
  final bool busy;
  final String? errorMessage;
  final MyNotesView view;
  final List<NoteCategoryItem> categories;
  final int selectedCategoryId;
  final MyNotesFilter activeFilter;
  final List<NoteEntry> notes;
  final NotePaperType paperType;
  final String draftTitle;
  final List<NoteStroke> strokes;
  final Color selectedColor;
  final double strokeWidth;
  final NoteEntry? editingNote;
  final String? editorBackgroundImageUrl;

  List<NoteEntry> get visibleNotes {
    final sorted = <NoteEntry>[...notes]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return switch (activeFilter) {
      MyNotesFilter.all => sorted,
      MyNotesFilter.recent => sorted.take(8).toList(),
      MyNotesFilter.favorite => sorted.where((e) => e.isFavorite).toList(),
      MyNotesFilter.unarchived => sorted,
    };
  }

  MyNotesState copyWith({
    bool? loading,
    bool? busy,
    String? errorMessage,
    bool clearError = false,
    MyNotesView? view,
    List<NoteCategoryItem>? categories,
    int? selectedCategoryId,
    MyNotesFilter? activeFilter,
    List<NoteEntry>? notes,
    NotePaperType? paperType,
    String? draftTitle,
    List<NoteStroke>? strokes,
    Color? selectedColor,
    double? strokeWidth,
    NoteEntry? editingNote,
    bool clearEditingNote = false,
    String? editorBackgroundImageUrl,
    bool clearEditorBackgroundImageUrl = false,
  }) {
    return MyNotesState(
      loading: loading ?? this.loading,
      busy: busy ?? this.busy,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      view: view ?? this.view,
      categories: categories ?? this.categories,
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      activeFilter: activeFilter ?? this.activeFilter,
      notes: notes ?? this.notes,
      paperType: paperType ?? this.paperType,
      draftTitle: draftTitle ?? this.draftTitle,
      strokes: strokes ?? this.strokes,
      selectedColor: selectedColor ?? this.selectedColor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      editingNote: clearEditingNote ? null : (editingNote ?? this.editingNote),
      editorBackgroundImageUrl: clearEditorBackgroundImageUrl
          ? null
          : (editorBackgroundImageUrl ?? this.editorBackgroundImageUrl),
    );
  }
}
