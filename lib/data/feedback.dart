import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/settings.dart';
import 'models.dart';

/// Отзыв о карточке вида — с заметкой; хранится на устройстве.
enum FeedbackKind {
  like('Мне нравится', Icons.favorite_border),
  wrongId('Неправильная идентификация', Icons.report_gmailerrorred),
  contentError('Ошибка в содержании', Icons.edit_note),
  moreTips('Больше рекомендаций', Icons.tips_and_updates_outlined);

  const FeedbackKind(this.label, this.icon);
  final String label;
  final IconData icon;
}

class FeedbackNote {
  const FeedbackNote({
    required this.id,
    required this.species,
    required this.kind,
    required this.text,
    required this.createdAt,
  });

  final String id;

  /// Латинское название вида.
  final String species;
  final FeedbackKind kind;
  final String text;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'species': species,
    'kind': kind.name,
    'text': text,
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  factory FeedbackNote.fromJson(Map<String, dynamic> j) => FeedbackNote(
    id: j['id'] as String,
    species: j['species'] as String,
    kind: FeedbackKind.values.asNameMap()[j['kind']] ?? FeedbackKind.like,
    text: j['text'] as String? ?? '',
    createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
  );
}

final feedbackProvider =
    NotifierProvider<FeedbackController, List<FeedbackNote>>(
      FeedbackController.new,
    );

class FeedbackController extends Notifier<List<FeedbackNote>> {
  static const _key = 'feedback.notes';

  @override
  List<FeedbackNote> build() {
    final raw = ref.read(sharedPrefsProvider).getString(_key);
    if (raw == null) return const [];
    try {
      return (jsonDecode(raw) as List)
          .map(
            (e) => FeedbackNote.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _save(List<FeedbackNote> notes) async {
    state = notes;
    await ref
        .read(sharedPrefsProvider)
        .setString(_key, jsonEncode(notes.map((n) => n.toJson()).toList()));
  }

  Future<void> add(String species, FeedbackKind kind, String text) => _save([
    FeedbackNote(
      id: newId(),
      species: species,
      kind: kind,
      text: text,
      createdAt: DateTime.now(),
    ),
    ...state,
  ]);

  Future<void> remove(String id) =>
      _save(state.where((n) => n.id != id).toList());

  List<FeedbackNote> forSpecies(String latin) =>
      state.where((n) => n.species == latin).toList();
}
