import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/vocabulary_item.dart';
import '../../providers/language_mode_provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../widgets/add_word_dialog.dart';
import '../widgets/ai_import_hub_dialog.dart';
import '../widgets/word_detail_panel.dart';

class VocabularyLibraryView extends ConsumerStatefulWidget {
  const VocabularyLibraryView({super.key});

  @override
  ConsumerState<VocabularyLibraryView> createState() =>
      _VocabularyLibraryViewState();
}

class _VocabularyLibraryViewState extends ConsumerState<VocabularyLibraryView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addWord() async {
    await AddWordDialog.show(
      context,
      initialLanguage: ref.read(languageModeProvider),
    );
    await ref.read(vocabularyProvider.notifier).loadInitialData();
  }

  Future<void> _import() async {
    await AiImportHubDialog.show(context);
    await ref.read(vocabularyProvider.notifier).loadInitialData();
  }

  void _select(VocabularyItem item) {
    ref.read(vocabularyProvider.notifier).selectWord(item);
    if (ResponsiveHelper.isMobile(context)) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (sheetContext) => SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.9,
          child: WordDetailPanel(
            item: item,
            onClose: () => Navigator.pop(sheetContext),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vocabularyProvider);
    final selected = state.selectedWord;
    final isDesktop = ResponsiveHelper.isDesktop(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sổ từ cá nhân',
                          style: GoogleFonts.outfit(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${state.searchResults.length} từ trong khóa học hiện tại',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _import,
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: const Text('AI Import'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _addWord,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Thêm từ'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: ref.read(vocabularyProvider.notifier).search,
                      decoration: InputDecoration(
                        hintText:
                            'Tìm theo từ, nghĩa, IPA, Pinyin hoặc Hán-Việt…',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _searchController.text.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  ref
                                      .read(vocabularyProvider.notifier)
                                      .search('');
                                  setState(() {});
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  PopupMenuButton<String?>(
                    tooltip: 'Lọc theo trình độ',
                    onSelected: ref
                        .read(vocabularyProvider.notifier)
                        .filterByLevel,
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: null,
                        child: Text('Mọi trình độ'),
                      ),
                      for (final level in const [
                        'A1',
                        'A2',
                        'B1',
                        'B2',
                        'HSK 1',
                        'HSK 2',
                        'HSK 3',
                      ])
                        PopupMenuItem(value: level, child: Text(level)),
                    ],
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.filter_list_rounded, size: 20),
                          const SizedBox(width: 8),
                          Text(state.selectedLevel ?? 'Trình độ'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : state.searchResults.isEmpty
              ? _LibraryEmpty(onAdd: _addWord)
              : Row(
                  children: [
                    Expanded(
                      flex: isDesktop ? 5 : 1,
                      child: _WordList(
                        items: state.searchResults,
                        selected: selected,
                        onSelect: _select,
                      ),
                    ),
                    if (isDesktop) ...[
                      const VerticalDivider(width: 1),
                      Expanded(
                        flex: 4,
                        child: selected == null
                            ? const _SelectWordHint()
                            : WordDetailPanel(
                                key: ValueKey(selected.id),
                                item: selected,
                              ),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _WordList extends StatelessWidget {
  const _WordList({
    required this.items,
    required this.selected,
    required this.onSelect,
  });
  final List<VocabularyItem> items;
  final VocabularyItem? selected;
  final ValueChanged<VocabularyItem> onSelect;

  @override
  Widget build(BuildContext context) => ListView.separated(
    key: const PageStorageKey('v2-word-library'),
    padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
    itemCount: items.length,
    separatorBuilder: (_, _) => const Divider(height: 1),
    itemBuilder: (context, index) {
      final item = items[index];
      final isSelected = selected?.id == item.id;
      return Material(
        color: isSelected
            ? AppColors.primaryEnglish.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          onTap: () => onSelect(item),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 8,
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  item.word,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (item.level != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    item.level!,
                    style: const TextStyle(
                      color: AppColors.accentDeep,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              [
                if (item.phonetic?.isNotEmpty == true) item.phonetic!,
                item.meaningVi,
              ].join('  •  '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
      );
    },
  );
}

class _LibraryEmpty extends StatelessWidget {
  const _LibraryEmpty({required this.onAdd});
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.bookmark_add_outlined, size: 56),
        const SizedBox(height: 14),
        const Text('Chưa tìm thấy từ phù hợp.'),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Thêm từ mới'),
        ),
      ],
    ),
  );
}

class _SelectWordHint extends StatelessWidget {
  const _SelectWordHint();
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.touch_app_outlined,
          size: 48,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 12),
        Text(
          'Chọn một từ để xem chi tiết',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    ),
  );
}
