import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/health/domain/health_models.dart';

void main() {
  test('自查快照按后端 DTO 编码选项题、无选项题和文本题', () {
    const lists = [
      SelfCheckList(
        id: 1,
        name: '常见症状',
        type: 'PUBLIC',
        categoryId: 3,
        questions: [
          SelfCheckQuestion(
            id: 10,
            text: '呕吐情况',
            type: SelfCheckQuestionType.single,
            required: false,
            sortOrder: 1,
            options: [SelfCheckOption(id: 101, text: '黄色呕吐物', sortOrder: 1)],
          ),
          SelfCheckQuestion(
            id: 20,
            text: '精神不振',
            type: SelfCheckQuestionType.single,
            required: false,
            sortOrder: 2,
            options: [],
          ),
          SelfCheckQuestion(
            id: 30,
            text: '其他表现',
            type: SelfCheckQuestionType.text,
            required: false,
            sortOrder: 3,
            options: [],
          ),
        ],
      ),
    ];

    final snapshot = buildSelfCheckSnapshot(
      lists: lists,
      selectedOptions: const {
        10: {101},
        20: {20},
      },
      textAnswers: const {30: '夜间频繁舔毛'},
    );

    final questions = snapshot.single['questions']! as List;
    expect(questions, hasLength(3));
    expect(
      questions[0],
      containsPair('options', [
        {'optionId': 101, 'optionText': '黄色呕吐物', 'selected': true},
      ]),
    );
    expect(
      questions[1],
      containsPair('options', [
        {'optionId': 20, 'optionText': '精神不振', 'selected': true},
      ]),
    );
    expect(
      questions[2],
      containsPair('options', [
        {'optionId': 30, 'optionText': '夜间频繁舔毛', 'selected': true},
      ]),
    );
    expect(questions[2], isNot(contains('answer')));
  });
}
