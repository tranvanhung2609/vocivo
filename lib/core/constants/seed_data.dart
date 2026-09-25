import '../../models/vocabulary_item.dart';

class SeedData {
  static List<VocabularyItem> get initialVocabulary => [
    // -------------------------------------------------------------
    // CHINESE SEED DATA (with Han-Viet, Pinyin tones, HSK & breakdown)
    // -------------------------------------------------------------
    VocabularyItem(
      languageCode: 'ZH',
      word: '学习',
      phonetic: 'xuéxí',
      hanViet: 'Học tập',
      meaningVi: 'Học tập, nghiên cứu, rèn luyện',
      wordType: 'verb',
      level: 'HSK 1',
      notes: '学 (Học: tiếp thu tri thức) + 习 (Tập: thực hành lặp lại)',
      examples: [
        ExampleSentence(
          text: '我们每天都要学习汉语。',
          pinyin: 'Wǒmen měitiān dōu yào xuéxí hànyǔ.',
          vi: 'Chúng tôi ngày nào cũng phải học tiếng Trung.',
        ),
        ExampleSentence(
          text: '活到老，学到老。',
          pinyin: 'Huó dào lǎo, xué dào lǎo.',
          vi: 'Học, học nữa, học mãi (Sống đến già, học đến già).',
        ),
      ],
    ),
    VocabularyItem(
      languageCode: 'ZH',
      word: '经济',
      phonetic: 'jīngjì',
      hanViet: 'Kinh tế',
      meaningVi: 'Kinh tế, nền kinh tế; tiết kiệm',
      wordType: 'noun / adj',
      level: 'HSK 4',
      notes: '经 (Kinh: kinh bang, quản lý) + 济 (Tế: tế thế, giúp đời)',
      examples: [
        ExampleSentence(
          text: '中国经济发展非常迅速。',
          pinyin: 'Zhōngguó jīngjì fāzhǎn fēicháng xùnsù.',
          vi: 'Kinh tế Trung Quốc phát triển rất nhanh chóng.',
        ),
        ExampleSentence(
          text: '这种做法既实用又经济。',
          pinyin: 'Zhè zhǒng zuòfǎ jì shíyòng yòu jīngjì.',
          vi: 'Cách làm này vừa thiết thực lại vừa tiết kiệm.',
        ),
      ],
    ),
    VocabularyItem(
      languageCode: 'ZH',
      word: '发展',
      phonetic: 'fāzhǎn',
      hanViet: 'Phát triển',
      meaningVi: 'Phát triển, mở rộng quy mô hoặc trình độ',
      wordType: 'verb / noun',
      level: 'HSK 3',
      notes: '发 (Phát: sinh sôi, bung nở) + 展 (Triển: mở rộng, duỗi ra)',
      examples: [
        ExampleSentence(
          text: '科学技术在飞速发展。',
          pinyin: 'Kēxué jìshù zài fēisù fāzhǎn.',
          vi: 'Khoa học kỹ thuật đang phát triển thần tốc.',
        ),
      ],
    ),
    VocabularyItem(
      languageCode: 'ZH',
      word: '坚持',
      phonetic: 'jiānchí',
      hanViet: 'Kiên trì',
      meaningVi: 'Kiên trì, giữ vững lập trường không từ bỏ',
      wordType: 'verb',
      level: 'HSK 4',
      notes: '坚 (Kiên: cứng rắn, vững chãi) + 持 (Trì: nắm giữ, duy trì)',
      examples: [
        ExampleSentence(
          text: '只要坚持下去，就一定能成功。',
          pinyin: 'Zhǐyào jiānchí xiàqù, jiù yídìng néng chénggōng.',
          vi: 'Chỉ cần kiên trì tới cùng, nhất định sẽ thành công.',
        ),
      ],
    ),
    VocabularyItem(
      languageCode: 'ZH',
      word: '挑战',
      phonetic: 'tiǎozhàn',
      hanViet: 'Khiêu chiến',
      meaningVi: 'Thử thách, thách thức',
      wordType: 'noun / verb',
      level: 'HSK 4',
      notes: '挑 (Khiêu: khêu gợi, gánh vác) + 战 (Chiến: trận đánh, chiến đấu)',
      examples: [
        ExampleSentence(
          text: '面对困难，我们要勇于接受挑战。',
          pinyin: 'Miànduì kùnnán, wǒmen yào yǒngyú jiēshòu tiǎozhàn.',
          vi: 'Đối mặt với khó khăn, chúng ta cần dũng cảm đón nhận thử thách.',
        ),
      ],
    ),
    VocabularyItem(
      languageCode: 'ZH',
      word: '幸福',
      phonetic: 'xìngfú',
      hanViet: 'Hạnh phúc',
      meaningVi: 'Hạnh phúc, sung sướng, bình an',
      wordType: 'noun / adj',
      level: 'HSK 3',
      notes: '幸 (Hạnh: may mắn, phúc lành) + 福 (Phúc: phúc khí, an lành)',
      examples: [
        ExampleSentence(
          text: '祝你们生活美满幸福！',
          pinyin: 'Zhù nǐmen shēnghuó měimǎn xìngfú!',
          vi: 'Chúc hai bạn cuộc sống viên mãn hạnh phúc!',
        ),
      ],
    ),
    VocabularyItem(
      languageCode: 'ZH',
      word: '成功',
      phonetic: 'chénggōng',
      hanViet: 'Thành công',
      meaningVi: 'Thành công, đạt được mục tiêu',
      wordType: 'verb / noun',
      level: 'HSK 3',
      notes: '成 (Thành: hoàn tất, trọn vẹn) + 功 (Công: công lao, kết quả)',
      examples: [
        ExampleSentence(
          text: '失败乃成功之母。',
          pinyin: 'Shībài nǎi chénggōng zhī mǔ.',
          vi: 'Thất bại là mẹ thành công.',
        ),
      ],
    ),
    VocabularyItem(
      languageCode: 'ZH',
      word: '影响',
      phonetic: 'yǐngxiǎng',
      hanViet: 'Ảnh hưởng',
      meaningVi: 'Ảnh hưởng, tác động đến',
      wordType: 'verb / noun',
      level: 'HSK 3',
      notes: '影 (Ảnh: bóng hình) + 响 (Hưởng: tiếng vang, dội lại)',
      examples: [
        ExampleSentence(
          text: '父母的言行会深刻影响孩子。',
          pinyin: 'Fùmǔ de yánxíng huì shēnkè yǐngxiǎng háizi.',
          vi: 'Lời nói và hành động của cha mẹ sẽ ảnh hưởng sâu sắc đến con cái.',
        ),
      ],
    ),
    VocabularyItem(
      languageCode: 'ZH',
      word: '责任',
      phonetic: 'zérèn',
      hanViet: 'Trách nhiệm',
      meaningVi: 'Trách nhiệm, bổn phận phải gánh vác',
      wordType: 'noun',
      level: 'HSK 5',
      notes: '责 (Trách: chức trách, đòi hỏi) + 任 (Nhiệm: đảm nhiệm, gánh vác)',
      examples: [
        ExampleSentence(
          text: '每个人都应该对自己的行为负责任。',
          pinyin: 'Měi gèrén dōu yīnggāi duì zìjǐ de xíngwéi fù zérèn.',
          vi: 'Mỗi người đều nên có trách nhiệm với hành vi của chính mình.',
        ),
      ],
    ),
    VocabularyItem(
      languageCode: 'ZH',
      word: '态度',
      phonetic: 'tàidu',
      hanViet: 'Thái độ',
      meaningVi: 'Thái độ, cách nhìn nhận và ứng xử',
      wordType: 'noun',
      level: 'HSK 4',
      notes: '态 (Thái: thần thái, dáng vẻ) + 度 (Độ: mức độ, chừng mực)',
      examples: [
        ExampleSentence(
          text: '态度决定一切。',
          pinyin: 'Tàidu juédìng yíqiè.',
          vi: 'Thái độ quyết định tất cả.',
        ),
      ],
    ),
    VocabularyItem(
      languageCode: 'ZH',
      word: '自律',
      phonetic: 'zìlǜ',
      hanViet: 'Tự luật',
      meaningVi: 'Tự giác, tính kỷ luật bản thân',
      wordType: 'noun / verb',
      level: 'HSK 5',
      notes: '自 (Tự: chính mình) + 律 (Luật: quy tắc, khuôn phép)',
      examples: [
        ExampleSentence(
          text: '高度的自律才能带来真正的自由。',
          pinyin: 'Gāodù de zìlǜ cái néng dàilái zhēnzhèng de zìyóu.',
          vi: 'Kỷ luật bản thân ở mức độ cao mới mang lại tự do thực sự.',
        ),
      ],
    ),
    VocabularyItem(
      languageCode: 'ZH',
      word: '毅力',
      phonetic: 'yìlì',
      hanViet: 'Nghị lực',
      meaningVi: 'Nghị lực, ý chí bền bỉ vượt khó',
      wordType: 'noun',
      level: 'HSK 6',
      notes: '毅 (Nghị: kiên quyết, can đảm) + 力 (Lực: sức mạnh)',
      examples: [
        ExampleSentence(
          text: '他凭借顽强的毅力战胜了病魔。',
          pinyin: 'Tā píngjiè wánqiáng de yìlì zhànshèng le bìngmó.',
          vi: 'Anh ấy nhờ vào nghị lực kiên cường đã chiến thắng bệnh tật.',
        ),
      ],
    ),

    // -------------------------------------------------------------
    // ENGLISH SEED DATA (with IPA, CEFR Level, Collocations, Examples)
    // -------------------------------------------------------------
    VocabularyItem(
      languageCode: 'EN',
      word: 'resilient',
      phonetic: '/rɪˈzɪl.jənt/',
      meaningVi: 'Kiên cường, mau phục hồi sau biến cố',
      wordType: 'adjective',
      level: 'B2',
      collocations: ['highly resilient', 'resilient economy', 'resilient mindset'],
      notes: 'Từ gốc Latin "resilire" (bật nảy trở lại)',
      examples: [
        ExampleSentence(
          text: 'Children are often remarkably resilient in tough situations.',
          vi: 'Trẻ em thường kiên cường và thích ứng đáng kinh ngạc trong hoàn cảnh khó khăn.',
        ),
        ExampleSentence(
          text: 'The local economy proved resilient despite global supply disruptions.',
          vi: 'Nền kinh tế địa phương tỏ ra kiên cường bất chấp đứt gãy chuỗi cung ứng toàn cầu.',
        ),
      ],
    ),
    VocabularyItem(
      languageCode: 'EN',
      word: 'meticulous',
      phonetic: '/məˈtɪk.jə.ləs/',
      meaningVi: 'Tỉ mỉ, cẩn thận từng chi tiết nhỏ',
      wordType: 'adjective',
      level: 'C1',
      collocations: ['meticulous attention to detail', 'meticulous research', 'meticulously planned'],
      notes: 'Đồng nghĩa: thorough, conscientious, painstaking',
      examples: [
        ExampleSentence(
          text: 'She is meticulous about keeping all her project records organized.',
          vi: 'Cô ấy rất tỉ mỉ trong việc giữ cho toàn bộ hồ sơ dự án luôn ngăn nắp.',
        ),
      ],
    ),
    VocabularyItem(
      languageCode: 'EN',
      word: 'serendipity',
      phonetic: '/ˌser.ənˈdɪp.ə.ti/',
      meaningVi: 'Sự may mắn tình cờ, cơ duyên bất ngờ',
      wordType: 'noun',
      level: 'C2',
      collocations: ['pure serendipity', 'stroke of serendipity'],
      notes: 'Bắt nguồn từ câu chuyện cổ tích "Ba hoàng tử của Serendip"',
      examples: [
        ExampleSentence(
          text: 'Finding my current co-founder in a coffee shop was pure serendipity.',
          vi: 'Việc gặp được người đồng sáng lập hiện tại ở quán cà phê là một cơ duyên hoàn toàn bất ngờ.',
        ),
      ],
    ),
    VocabularyItem(
      languageCode: 'EN',
      word: 'pragmatic',
      phonetic: '/præɡˈmæt.ɪk/',
      meaningVi: 'Thực tế, thực dụng, chú trọng tính ứng dụng',
      wordType: 'adjective',
      level: 'C1',
      collocations: ['pragmatic approach', 'pragmatic solution', 'pragmatic leader'],
      notes: 'Trái nghĩa: idealistic, impractical',
      examples: [
        ExampleSentence(
          text: 'We need a pragmatic approach to tackle this technical debt.',
          vi: 'Chúng ta cần một hướng tiếp cận thực tế để xử lý món nợ kỹ thuật này.',
        ),
      ],
    ),
    VocabularyItem(
      languageCode: 'EN',
      word: 'articulate',
      phonetic: '/ɑːˈtɪk.jə.lət/',
      meaningVi: 'Ăn nói lưu loát, diễn đạt mạch lạc, khúc chiết',
      wordType: 'adjective / verb',
      level: 'B2',
      collocations: ['articulate speaker', 'clearly articulate', 'highly articulate'],
      notes: 'Động từ: articulate (/ɑːˈtɪk.jə.leɪt/) nghĩa là phát biểu rõ ràng',
      examples: [
        ExampleSentence(
          text: 'She gave an articulate and persuasive presentation to the investors.',
          vi: 'Cô ấy đã có bài thuyết trình mạch lạc và đầy tính thuyết phục trước các nhà đầu tư.',
        ),
      ],
    ),
    VocabularyItem(
      languageCode: 'EN',
      word: 'diligent',
      phonetic: '/ˈdɪl.ɪ.dʒənt/',
      meaningVi: 'Cần cù, chăm chỉ, chuyên cần',
      wordType: 'adjective',
      level: 'B1',
      collocations: ['diligent student', 'diligent worker', 'diligent efforts'],
      notes: 'Danh từ: diligence (sự chuyên cần)',
      examples: [
        ExampleSentence(
          text: 'Through diligent study and daily practice, he mastered programming.',
          vi: 'Nhờ học tập chăm chỉ và luyện tập hằng ngày, anh ấy đã thành thạo lập trình.',
        ),
      ],
    ),
    VocabularyItem(
      languageCode: 'EN',
      word: 'versatile',
      phonetic: '/ˈvɜː.sə.taɪl/',
      meaningVi: 'Đa năng, linh hoạt, thích ứng nhiều vai trò',
      wordType: 'adjective',
      level: 'B2',
      collocations: ['versatile tool', 'versatile actor', 'versatile skillset'],
      notes: 'Thường dùng khen ngợi kỹ năng của kỹ sư hoặc tính năng của phần mềm',
      examples: [
        ExampleSentence(
          text: 'Flutter is a versatile framework capable of building mobile, web and desktop apps.',
          vi: 'Flutter là một nền tảng đa năng có khả năng xây dựng ứng dụng di động, web và máy tính.',
        ),
      ],
    ),
    VocabularyItem(
      languageCode: 'EN',
      word: 'empathy',
      phonetic: '/ˈem.pə.θi/',
      meaningVi: 'Sự thấu cảm, khả năng đặt mình vào vị trí người khác',
      wordType: 'noun',
      level: 'B2',
      collocations: ['feel empathy for', 'deep empathy', 'develop empathy'],
      notes: 'Khác với sympathy (sự thương hại, đồng cảm nông hơn)',
      examples: [
        ExampleSentence(
          text: 'Great product design always starts with empathy for the user.',
          vi: 'Thiết kế sản phẩm xuất sắc luôn bắt đầu từ sự thấu cảm sâu sắc đối với người dùng.',
        ),
      ],
    ),
  ];
}
